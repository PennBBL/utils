#QA_template_config.R
study="eons_xnat"
scandir="\"*_bbl1_idemo2_210\""
featdir="\"stats\*nobehave*\""
file=""
filepath="\"*_bbl1_idemo2_210/stats/*_bbl1_idemo2_210_SEQ*_eons_idemo_nobehave_stats_*.feat/reg_std_ants/example_func2standard_2mm.nii.gz\""
coverage_file="/import/speedy/eons/progs/idemo_speedy/n1601_QA_scripts/n1601_coverage_check.csv"
incidental<-read.csv("/import/monstrum/eons_xnat/redcap/subject_variables/n1601_incidental_findings_ts.csv")
feat="\"*idemo_behav_incorr*\""
regfile="/import/speedy/eons/progs/idemo_speedy/n1601_QA_scripts/n1601_registration_check.csv"
reviewfile="/import/speedy/eons/progs/idemo_speedy/n1601_QA_scripts/n1601_registration_and_coverage_review.csv"
mask="/import/monstrum/eons_xnat/group_results_n1445/idemo/merged4D_images/n968_mask.nii.gz"
qapath=""



