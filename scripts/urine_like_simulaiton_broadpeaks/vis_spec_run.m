close all;
clear all;
%% Set your toolbox paths; functions imported from these directories:
% Metabolic toolbox toolbox found @  https://github.com/artedison/Edison_Lab_Shared_Metabolomics_UGA
localPaths.public_toolbox='/Users/yuewu/Documents/GitHub/Edison_Lab_Shared_Metabolomics_UGA/';
% NMR decompositon program found @ https://github.com/edisonomics/SAND
localPaths.nmrdecomp_path='/Users/yuewu/Documents/GitHub/SAND/';
addpath(genpath(localPaths.public_toolbox));
addpath(genpath(localPaths.nmrdecomp_path));
pause(1),clc
% the path should be changed accordingly in hte users' computer
paredir='/Users/yuewu/Dropbox (Edison_Lab@UGA)/Projects/Bioinformatics_modeling/spec_deconv_time_domain/result/publicaiton_spec_decomp/'
projdir=[paredir 'result_reproduce/urine_like_simulaiton_broadpeaks/'];
datadir=[paredir 'data/urine_fitting/'];
libdir=[datadir 'test_trans.fid'];% a template fid file containing useful header information. https://www.dropbox.com/s/1i0dixw4vasctwu/test_trans.fid?dl=0
preresdirpath=[projdir 'res/deconv/res/res/'];
craftdir=[projdir 'res/CRAFT_result/simudata2_CRAFT4YueWu/'];
cd([projdir]);
% load original simulation information
load([projdir 'res/saved_simulation.mat']);
specppm=ppm_r;
%
sampleseq=1:nsample;
ppmrange_dss=[-0.1 0.1];
deltapm_threshold=0.002;%distance threshold for peak matching
% vis check of the deconv
for i=sampleseq
  foldpath=[preresdirpath num2str(i) '/'];
  dircont=dir([foldpath '*ft*.fig'])
  figpath=[foldpath dircont.name];
  uiopen(figpath,1);
end
close all;
obj_refine=[];
time_cost=[];
for runid=sampleseq
  load([preresdirpath num2str(runid) '/runid' num2str(runid) '_refine_res.mat']);
  obj_refine=[obj_refine obj_scaled];
  time_cost=[time_cost timecost];
end
tab_eval=table(sampleseq',obj_refine',time_cost','VariableNames',{'id','obj_refine','time_cost'});
save('performance_eval.mat','tab_eval');
% mean performance
mean(log10(tab_eval{:,'obj_refine'}))
% mean time
mean(tab_eval{:,'time_cost'})

% stack plot
visregion=[6.9 8.6];
regb=sort(matchPPMs(visregion,specppm));
visseq=regb(1):regb(2);
stackSpectra(specmat(:,visseq),specppm(visseq),0.0,50,'decompose of one nmr data set')
fig=gcf;
saveas(fig,['stack_whole.fig']);
close all;
% remove broad peaks
groundtruth_tab=groundtruth_tab(groundtruth_tab{:,'lambda'}<=15,:);
% ground truth
for sampi=sampleseq
  rowinds=find(groundtruth_tab{:,'simulation'}==sampi);
  temptab=groundtruth_tab(rowinds,:);
  temptab{:,'frequency'}=temptab{:,'frequency'}/para_add_list.conv_f(2)+para_add_list.conv_f(1);
  regind=temptab{:,1}>ppmrange_dss(1) & temptab{:,1}<ppmrange_dss(2);
  dssconc=max(temptab{regind,'A'});
  temptab{:,'A'}=temptab{:,'A'}/dssconc;%normalize to DSS
  groundtruth_tab(rowinds,:)=temptab;
end
groundtruth_tab.Properties.VariableNames={'PPM','lambda','A','phase','simulation'};

% load decomposation estimation of different spectra
namelist={};
est_tab=[];%PPM, lambda, A, simulation_ind
for sampi=1:nsample
  sample=sampleseq(sampi);
  samplestr=num2str(sample);
  load([preresdirpath samplestr '/runid' samplestr '_env_final.mat']);
  runtab=array2table(tabsumm_refine,'VariableNames',{'PPM','lambda','A','phase'});%f, lambda, A, phi
  nfeature=size(runtab,1);
  runtab{:,'PPM'}=runtab{:,'PPM'}/para_add_list.conv_f(2)+para_add_list.conv_f(1);
  % DSS intenstiy
  regind=runtab{:,'PPM'}>ppmrange_dss(1) & runtab{:,'PPM'}<ppmrange_dss(2);
  dssconc=max(runtab{regind,'A'});
  runtab{:,'A'}=runtab{:,'A'}/dssconc;%normalize to DSS
  simu=repmat(sampi,[nfeature,1]);
  runtab=[runtab table(simu)];
  namelist=[namelist; {repmat({'unknown'},[1,nfeature])}];
  est_tab=[est_tab; runtab];
end
est_tab.Properties.VariableNames={'PPM','lambda','A','phase','simulation'};

% load CRAFT estimation of different spectra
est_craft_tab=[];%PPM, lambda, A, simulation_ind
for sampi=1:nsample
  sample=sampleseq(sampi);
  samplestr=num2str(sample);
  tab_craft=readtable([craftdir samplestr '_fidLL.txt'],'HeaderLines',5);
  runtab=tab_craft(:,[1,3,2,4]);
  runtab.Properties.VariableNames={'PPM','lambda','A','phase'};
  runtab{:,'PPM'}=para_add_list.conv_f(1)*2-runtab{:,'PPM'};%mirror simmetry transform
  % runtab{:,'PPM'}=(runtab{:,'PPM'}-para_add_list.conv_f(1))*para_add_list.conv_f(2);
  runtab{:,'phase'}=runtab{:,'phase'}/360*2*pi;
  nfeature=size(runtab,1);
  % DSS intenstiy
  regind=runtab{:,'PPM'}>ppmrange_dss(1) & runtab{:,'PPM'}<ppmrange_dss(2);
  dssconc=max(runtab{regind,'A'});
  runtab{:,'A'}=runtab{:,'A'}/dssconc;%normalize to DSS
  simu=repmat(sampi,[nfeature,1]);
  runtab=[runtab table(simu)];
  est_craft_tab=[est_craft_tab; runtab];
end
est_craft_tab.Properties.VariableNames={'PPM','lambda','A','phase','simulation'};
%intensity and integral based estimation
est_other_tab=[];
for sampi=1:size(specmat,1)
  spec_here=specmat(sampi,:);
  runtab=[];
  for bini=1:size(binrange,1)
    ppmrange=binrange(bini,:);
    [indrang]=sort(matchPPMs(ppmrange,specppm));
    indseq=indrang(1):indrang(2);
    spec_reg_shift=spec_here(indseq);
    baseval=min(spec_reg_shift);
    % baseval=0;
    [est_inten maxind]=max(spec_reg_shift-baseval);
    est_auc=trapz(spec_reg_shift-baseval);
    est_temp_tab=table(specppm(indrang(1)+maxind-1),nan,est_inten,est_auc,0,sampi);
    runtab=[runtab; est_temp_tab];
  end
  regind=runtab{:,1}>ppmrange_dss(1) & runtab{:,1}<ppmrange_dss(2);
  %normalize to DSS
  runtab{:,3}=runtab{:,3}/max(runtab{regind,3});
  runtab{:,4}=runtab{:,4}/max(runtab{regind,4});
  est_other_tab=[est_other_tab; runtab];
end
est_other_tab.Properties.VariableNames={'PPM','lambda','intensity','integral','phase','simulation'};
%
quan_str=struct();
quan_str.deconv=est_tab;
quan_str.craft=est_craft_tab;
quan_str.intensity=est_other_tab(:,{'PPM','lambda','intensity','phase','simulation'});
quan_str.integral=est_other_tab(:,{'PPM','lambda','integral','phase','simulation'});
% select within interested ppm range
selerange=[6.8 8.6; -0.1 0.1];% considered ppm range
for type=fieldnames(quan_str)'
  type=type{1};
  tempdata=quan_str.(type);
  rowind_ppm=find(tempdata{:,'PPM'}>selerange(1,1)&tempdata{:,'PPM'}<selerange(1,2) | tempdata{:,'PPM'}>selerange(2,1)&tempdata{:,'PPM'}<selerange(2,2));
  tempdata=tempdata(rowind_ppm,:);
  quan_str.(type)=tempdata;
end
% match estimation with ground truth
thres_ppm_del=0.01;
summ_str=struct();
for type=fieldnames(quan_str)'
  type=type{1};
  summtab=[];
  rec_ratio=[];
  est_tab_temp=quan_str.(type);
  est_tab_temp.Properties.VariableNames={'PPM','lambda','A','phase','simulation'};
  for simui=sampleseq
    subtab_est=est_tab_temp(est_tab_temp{:,'simulation'}==simui,:);
    subtab_true=groundtruth_tab(groundtruth_tab{:,'simulation'}==simui,:);
    distmat=abs(pdist2(subtab_est{:,'PPM'},subtab_true{:,'PPM'}));
    %%%selecting out ppm points that are pairwise closest to each other
    [ppm_match_val1,ppm_match_ind1]=min(distmat,[],2);
    [ppm_match_val2,ppm_match_ind2]=min(distmat,[],1);
    ind_true=[];
    ind_est=[];
    ppm_match_val=[];
    for ppm_min_i=1:length(ppm_match_ind1)
      if ppm_match_ind2(ppm_match_ind1(ppm_min_i))==ppm_min_i%check for pairwise match
        ppm_match_val=[ppm_match_val ppm_match_val1(ppm_min_i)];
        ind_true=[ind_true ppm_match_ind1(ppm_min_i)];
        ind_est=[ind_est ppm_min_i];
      end
    end
    % filter by ppm distances
    thres_ind=find(ppm_match_val<deltapm_threshold);
    ind_est=ind_est(thres_ind);
    ind_true=ind_true(thres_ind);
    subtab_est_match=subtab_est(ind_est,{'PPM','A','lambda','phase'});
    subtab_est_match.Properties.VariableNames={'PPM_est','A_est','lambda_est','phase_est'};
    subtab_true_match=subtab_true(ind_true,{'PPM','A','lambda','phase','simulation'});
    subtab_true_match.Properties.VariableNames={'PPM_true','A_true','lambda_true','phase_true','simulation'};
    loctab_simu=[subtab_est_match subtab_true_match];
    % distinguish close peaks from others
    closppm=[];
    ppmvec_loc=subtab_est{:,'PPM'};
    for peaki=1:length(ppmvec_loc)
      ppmdist_min=min(abs(ppmvec_loc(1:end ~=peaki)-ppmvec_loc(peaki)));
      closppm=[closppm ppmdist_min<thres_ppm_del];
    end
    loctab_simu=addvars(loctab_simu,closppm(ind_est)','After','simulation','NewVariableNames','closepeaks');
    %
    summtab=[summtab; loctab_simu];
    rec_ratio=[rec_ratio size(subtab_est_match,1)/size(subtab_true,1)];
  end
  % summtab=summtab(summtab{:,'A_est'}>10^-3 & summtab{:,'A_true'}>10^-3,:);
  tempstr=struct();
  tempstr.summtab=summtab;
  tempstr.rec_ratio=rec_ratio;
  summ_str.(type)=tempstr;
end
% separate simulation with broad peaks and without in the evaluation
samptypes=unique(sampseq)';%no_broad_peak, with_broad_peak
smptypes_str={'nobroad','broad'};
evalu_str_types=struct();
for samptype=samptypes
  subind=find(sampseq==samptype)';
  % calculate evaluations
  evalu_str=struct();
  for type=fieldnames(quan_str)'
    type=type{1};
    summtab=summ_str.(type).summtab;
    rel_mse_vec=[];
    mse_vec=[];
    corxy_vec=[];
    k_vec=[];
    corxylambda_vec=[];
    klambda_vec=[];
    corxyf_vec=[];
    for simui=subind
      loctab=summtab(summtab{:,'simulation'}==simui,:);
      xvec=loctab{:,'A_true'};
      yvec=loctab{:,'A_est'};
      ndata=length(xvec);
      rel_mse_vec=[rel_mse_vec sum(((xvec-yvec)./mean([xvec yvec],2)).^2)/ndata];
      mse_vec=[mse_vec sum((xvec-yvec).^2)/ndata];
      corxy_vec=[corxy_vec corr(xvec,yvec)];
      dlm=fitlm(xvec,yvec,'Intercept',false);
      k_vec=[k_vec dlm.Coefficients.Estimate];
      %
      corxylambda_vec=[corxylambda_vec corr(loctab{:,'lambda_true'},loctab{:,'lambda_est'})];
      dlm=fitlm(loctab{:,'lambda_true'},loctab{:,'lambda_est'},'Intercept',false);
      klambda_vec=[klambda_vec dlm.Coefficients.Estimate];
      corxyf_vec=[corxyf_vec corr(loctab{:,'PPM_true'},loctab{:,'PPM_est'})];
    end
    evalu=struct();
    for eval_ele={'rel_mse' 'mse' 'corxy' 'k' 'corxylambda' 'corxyf' 'klambda'}
      eval_ele=eval_ele{1};
      locvec=eval([eval_ele '_vec']);
      evalu.(eval_ele)=mean(locvec);
      evalu.([eval_ele '_ste'])=std(locvec)/sqrt(length(locvec));
    end
    evalu_str.(type)=evalu;
  end
  % scattter plot
  for type=fieldnames(summ_str)'
    type=type{1};
    summtab=summ_str.(type).summtab;
    evalu=evalu_str.(type);
    h=figure();
      gscatter(summtab{:,'A_true'},summtab{:,'A_est'},summtab{:,'closepeaks'},[],[],[20]);
      xlabel('ground truth');
      ylabel('estimation');
      title([type ' correlation ' num2str(evalu.corxy), ' mse ' num2str(evalu.mse) ' k ' num2str(evalu.k)]);
    saveas(h,['scatter_simulation.' type '_' smptypes_str{samptype} '.fig']);
    close(h);
  end
  % peaks that are in simulation but not recoverd.
  rec_ratio_vec=[];
  for type=fieldnames(summ_str)'
    type=type{1};
    rec_ratio_vec=[rec_ratio_vec mean(summ_str.(type).rec_ratio)];
  end
  % lambda estimation decompositon
  summtab=summ_str.deconv.summtab;
  h=figure();
    gscatter(summtab{:,'lambda_true'},summtab{:,'lambda_est'},summtab{:,'closepeaks'},[],[],[20]);
    xlabel('ground truth');
    ylabel('estimation');
    title([' lambda correlation ' num2str(evalu_str.deconv.corxylambda) ' k ' num2str(evalu_str.deconv.klambda)]);
  saveas(h,['scatter_simulation' '_' smptypes_str{samptype} '_lambda.fig']);
  close(h);
  % PPM estimation decompositon
  h=figure();
    gscatter(summtab{:,'PPM_true'},summtab{:,'PPM_est'},summtab{:,'simulation'},[],[],[20]);
    xlabel('ground truth');
    ylabel('estimation');
    title([' PPM correlation ' num2str(evalu_str.deconv.corxyf)]);
    xlim([6.9 8.6]);
    ylim([6.9 8.6]);
  saveas(h,['scatter_simulation' '_' smptypes_str{samptype} '_PPM.fig']);
  close(h);
  % lambda estimation craft
  summtab=summ_str.craft.summtab;
  h=figure();
    gscatter(summtab{:,'lambda_true'},summtab{:,'lambda_est'},summtab{:,'simulation'},[],[],[20]);
    xlabel('ground truth');
    ylabel('estimation');
    title([' lambda correlation ' num2str(evalu_str.craft.corxylambda) ' k ' num2str(evalu_str.craft.klambda)]);
  saveas(h,['scatter_simulation' '_' smptypes_str{samptype} '_lambda_craft.fig']);
  close(h);
  % PPM estimation craft
  h=figure();
    gscatter(summtab{:,'PPM_true'},summtab{:,'PPM_est'},summtab{:,'simulation'},[],[],[20]);
    xlabel('ground truth');
    ylabel('estimation');
    title([' PPM correlation ' num2str(evalu_str.craft.corxyf)]);
    xlim([6.9 8.6]);
    ylim([6.9 8.6]);
  saveas(h,['scatter_simulation' '_' smptypes_str{samptype} '_PPM_craft.fig']);
  close(h);
  % corr(summtab{:,'lambda_true'},summtab{:,'lambda_est'})
  % phi estimation
  % unique(summ_str.deconv.summtab{:,'phase_est'})
  evalu_str_types.(smptypes_str{samptype})=evalu_str;
end
% make the table
evalu_tab=cell2table(cell(0,6),'VariableNames',{'rel_mse','mse','corxy','k', 'quan_method', 'broadpeak'});
for typeele=fieldnames(evalu_str_types)'
  typeele=typeele{1};
  locstr=evalu_str_types.(typeele);
  for methele=fieldnames(locstr)'
    methele=methele{1};
    loctab=struct2table(locstr.(methele));
    loctab=[loctab(:,{'rel_mse','mse','corxy','k'}) table({methele},'VariableNames',{'quan_method'}) table({typeele},'VariableNames',{'broadpeak'})];
    evalu_tab=[evalu_tab; loctab];
  end
end
save('evaluation.mat','evalu_str_types','evalu_tab');
writetable(evalu_tab,'stat_tab.txt');

% stack plot showing result for selected region
showsamp=[1 11];
exampregions=[[6.8:0.2:8.4]' [7.0:0.2:8.6]'];
for sampshowi=showsamp
  sampshowistr=num2str(sampshowi);
  load([projdir '/res/saved_simulation.mat']);
  load([preresdirpath sampshowistr '/runid' sampshowistr '_refine_res.mat']);
  load([preresdirpath sampshowistr '/runid' sampshowistr '_temp_store_step2.mat']);
  load([preresdirpath sampshowistr '/runid' sampshowistr '_trainingdata.mat']);
  groundtruth_subtab=groundtruth_tab{groundtruth_tab{:,'simulation'}==sampshowi,1:4};
  for regioni=1:size(exampregions,1)
    % raw spectra
    stackmat=ft_ori_tab{:,2}';
    %
    region_loc=exampregions(regioni,:);
    ppmpara=tabsumm_refine(:,1)/para_add_list.conv_f(2)+para_add_list.conv_f(1);
    ppmind=find(ppmpara>region_loc(1) & ppmpara<region_loc(2));
    tabpara_loc=tabsumm_refine(ppmind,:);
    ppmpara=groundtruth_subtab(:,1)/para_add_list.conv_f(2)+para_add_list.conv_f(1);
    ppmind=find(ppmpara>region_loc(1) & ppmpara<region_loc(2));
    tabtruth_loc=groundtruth_subtab(ppmind,:);
    nest=size(tabpara_loc,1);
    % remove broad peaks in groudtruth table
    tabtruth_loc(tabtruth_loc(:,2)>15,:)=[];
    ntruth=size(tabtruth_loc,1);
    % sort both tables
    [~,sortind]=sort(tabtruth_loc(:,1));
    tabtruth_loc=tabtruth_loc(sortind,:);
    [~,sortind]=sort(tabpara_loc(:,1));
    tabpara_loc=tabpara_loc(sortind,:);
    % the simulated spectra
    sumsig=sin_mixture_simu(tabpara_loc,timevec_sub_front,nan,'complex');
    scalfactor=0.5;
    sumsig(1)=sumsig(1)*scalfactor;
    sumsig=[zeros([shifttimeadd,1]); sumsig];
    spec_new_sum=ft_pipe(table([1:length(sumsig)]',real(sumsig),imag(sumsig)),libdir,num2str(regioni));
    stackmat=[stackmat; spec_new_sum{:,2}'];
    % each simulation component
    for paraseti=1:ntruth
      sumsig=sin_mixture_simu(tabtruth_loc(paraseti,:),timevec_sub_front,nan,'complex');
      scalfactor=0.5;
      sumsig(1)=sumsig(1)*scalfactor;
      sumsig=[zeros([shifttimeadd,1]); sumsig];
      spec_new_sum=ft_pipe(table([1:length(sumsig)]',real(sumsig),imag(sumsig)),libdir,num2str(paraseti));
      stackmat=[stackmat; spec_new_sum{:,2}'];
    end
    % each deconv component
    for paraseti=1:nest
      sumsig=sin_mixture_simu(tabpara_loc(paraseti,:),timevec_sub_front,nan,'complex');
      scalfactor=0.5;
      sumsig(1)=sumsig(1)*scalfactor;
      sumsig=[zeros([shifttimeadd,1]); sumsig];
      spec_new_sum=ft_pipe(table([1:length(sumsig)]',real(sumsig),imag(sumsig)),libdir,num2str(paraseti));
      stackmat=[stackmat; spec_new_sum{:,2}'];
    end
    % color settings
    colorset=struct();
    colorset.rgb=flip([[0 0 0]; [1 0 0]; repmat([0 0.7 0],[ntruth,1]); repmat([0 0 0.7],[nest,1])],1);
    colorset.categories=table(flip([{'ft'},{'sum'},{'truth'},{'estimation'}]'));
    colorset.colorList=flip([0 0 0; 1 0 0; 0 0.7 0; 0 0 0.7],1);
    %
    ppmvis_rang=sort(matchPPMs(region_loc,ppm));
    ppmvis_ind=ppmvis_rang(1):ppmvis_rang(2);
    stackmat=flip(stackmat,1);
    stackSpectra(stackmat(:,ppmvis_ind),ppm(ppmvis_ind),0.0,10,['example ' sampshowistr '_' num2str(regioni)],'colors',colorset);
    fig=gcf;
    saveas(fig,['stack_example_' sampshowistr '_' num2str(regioni) '.fig']);
    close all;
  end
end

% show case adding broad peaks
showsampi=11;
regshow=[7.0 7.5];
sampshowistr=num2str(showsampi);
load([projdir '/res/saved_simulation.mat']);
load([preresdirpath sampshowistr '/runid' sampshowistr '_refine_res.mat']);
load([preresdirpath sampshowistr '/runid' sampshowistr '_temp_store_step2.mat']);
load([preresdirpath sampshowistr '/runid' sampshowistr '_trainingdata.mat']);
groundtruth_subtab=groundtruth_tab{groundtruth_tab{:,'simulation'}==showsampi,1:4};
ppmpara=groundtruth_subtab(:,1)/para_add_list.conv_f(2)+para_add_list.conv_f(1);
ppmind=find(ppmpara>regshow(1) & ppmpara<regshow(2));
tabtruth_loc=groundtruth_subtab(ppmind,:);
broadmask=tabtruth_loc(:,2)>15;
tabtruth_loc_narrow=tabtruth_loc(~broadmask,:);
tabtruth_loc_broad=tabtruth_loc(broadmask,:);
%
[~,sortind]=sort(tabtruth_loc_broad(:,1));
tabtruth_loc_broad=tabtruth_loc_broad(sortind,:);
% raw spectra
stackmat=ft_ori_tab{:,2}';
% narrow spectra
% the simulated spectra
sumsig=sin_mixture_simu(tabtruth_loc_narrow,timevec_sub_front,nan,'complex');
scalfactor=0.5;
sumsig(1)=sumsig(1)*scalfactor;
sumsig=[zeros([shifttimeadd,1]); sumsig];
spec_new_sum=ft_pipe(table([1:length(sumsig)]',real(sumsig),imag(sumsig)),libdir,'narrow');
stackmat=[stackmat; spec_new_sum{:,2}'];
%
nbroad=size(tabtruth_loc_broad,1);
for paraseti=1:nbroad
  sumsig=sin_mixture_simu(tabtruth_loc_broad(paraseti,:),timevec_sub_front,nan,'complex');
  scalfactor=0.5;
  sumsig(1)=sumsig(1)*scalfactor;
  sumsig=[zeros([shifttimeadd,1]); sumsig];
  spec_new_sum=ft_pipe(table([1:length(sumsig)]',real(sumsig),imag(sumsig)),libdir,num2str(paraseti));
  stackmat=[stackmat; spec_new_sum{:,2}'];
end
colorset=struct();
colorset.rgb=flip([[0 0 0]; [1 0 0]; repmat([0 0.7 0],[nbroad,1])],1);
colorset.categories=table(flip([{'ft'},{'narrow'},{'broad'}]'));
colorset.colorList=flip([0 0 0; 1 0 0; 0 0.7 0],1);
%
ppmvis_rang=sort(matchPPMs(regshow,ppm));
ppmvis_ind=ppmvis_rang(1):ppmvis_rang(2);
stackmat=flip(stackmat,1);
stackSpectra(stackmat(:,ppmvis_ind),ppm(ppmvis_ind),0.0,0,['example ' sampshowistr '_' num2str(regioni)],'colors',colorset);
fig=gcf;
saveas(fig,['stack_example_broad.fig']);
close all;
