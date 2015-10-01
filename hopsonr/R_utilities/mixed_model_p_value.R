### mixed model p-value table
# this function takes as input fixed and random, both formula objects defined like
# form<-formula(delta1 ~ day * group) random<-list(formula(~1|bblid.x),formula(~1|scanid))
# data = a data frame containing values to be tested in long format
# roi_column = a string the same name as the column that contains your rois
mixed_model_p_value<-function(fixed=NULL,random=NULL,data=NULL,roi_column=NULL,second_name_column=F){
  require(nlme)
  #collect the pvalues
  pvalue_table<-data.frame()
for (roi in unique(data[[roi_column]])){
  model1<-lme(fixed,random,data=data[ data[[roi_column]]==roi,])
  anova.lme.out<-anova.lme(model1,type="marginal",adjustSigma=F)
  x<-data.frame(roi)
  z<-anova.lme.out[["p-value"]]
  z<-z[2:length(z)]
  x<-cbind(x,t(z))
  pvalue_table<-rbind(pvalue_table,x)
}
#adjust for multiple comparisons
colnames(pvalue_table)[2:ncol(pvalue_table)]<-row.names(anova.lme.out)[2:nrow(anova.lme.out)]
for (i in 2:ncol(pvalue_table)){
  pvalue_table[,i]<-p.adjust(pvalue_table[,i],method="fdr")
}
#add significance labels
pvalue_table2<-data.frame("roi"=(pvalue_table[,1]))
for (i in 2:ncol(pvalue_table)){pvalue_table2[,colnames(pvalue_table)[i]]<-pvalue_table[,i]   #<-cbind(pvalue_table2,three_sig[,i])
                              pvalue_table2[,paste(colnames(pvalue_table)[i],"_sig",sep="")]<-""
                              pvalue_table2[[paste(colnames(pvalue_table)[i],"_sig",sep="")]][which(pvalue_table[,i] <= 0.001)]<-"***"
                              pvalue_table2[[paste(colnames(pvalue_table)[i],"_sig",sep="")]][which(pvalue_table[,i] <= 0.01 & pvalue_table[,i] > 0.001)]<-"**"
                              pvalue_table2[[paste(colnames(pvalue_table)[i],"_sig",sep="")]][which(pvalue_table[,i] <= 0.05 & pvalue_table[,i] > 0.01)]<-"*"
                              pvalue_table2[[paste(colnames(pvalue_table)[i],"_sig",sep="")]][which(pvalue_table[,i] <= 0.1 & pvalue_table[,i] > 0.05)]<-"."
}
if(second_name_column){pvalue_table2$roi2<-pvalue_table2$roi}
return(pvalue_table2)
}
