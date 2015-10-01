#Originally designed for graphing %signal change data, this script with work for any bar graphs if the original data is in long form. Arguments:
#data: the data frame to be used - NO QUOTES
#roi_names: name of the column containg the names of roi names (column to be iterated over) - can be a dummy column if only making one graph
#value: name of the column containing the values to be meaned and plotted
#x.value: name of the column containing different task conditions to be plotted on the x-axis (i.e., nback level or tp,fp,tn,fn),determines labels on x-axis
#group.value: name of the column containing the factor by which participants are grouped (patients/controls, smoking/abstinent, etc) this determines column color and will be grouped together
#scale.fill: an optional data frame containing colors to be used
#ranges: an optional data frame containing the ranges to be used
#test: logical - should a t-test be performed to determine significance of results between groups (only works for 2 groups)
#paired: logical - are the groups paired
#x.title: title of x axis
#y.title: title of y axis

graphsigchange <- function(data=NULL, roi_names=NULL,value=NULL,x.value=NULL,group.value=NULL,scale.fill=NULL,ranges=NULL,test=FALSE,paired=FALSE,y.title="% Signal Change",x.title="Trial Type",graph.title=NULL,for.presentation=FALSE,x.axis.text.size=24,x.angle=0) {
  require(ggplot2)
  require(grid)
  roi_temp<-unique(data[[roi_names]])
  x<-data.frame()
  for (i in 1:length(roi_temp)){
    temp<-data[which(data[[roi_names]]==paste(roi_temp[i])),]
    temp[[x.value]]<-as.factor(temp[[x.value]])
    g.vars<-c(x.value,group.value)
    datasum<-summarySE(temp, measurevar=paste(value), groupvars=g.vars)
    assign("datasum",datasum,envir=.GlobalEnv)
    assign("x.value",x.value,envir=.GlobalEnv)
    assign("yvals",datasum[[value]],envir=.GlobalEnv)
    assign("group.value",group.value,envir=.GlobalEnv)
    graph.title2<-graph.title
    if (missing(graph.title)){
      graph.title2<-paste(roi_temp[i])
    }
    g<-ggplot(datasum,aes(x=datasum[[x.value]],y=yvals,fill=datasum[[group.value]]))+
      geom_bar(position=position_dodge(), stat="identity")+
      geom_errorbar(aes(ymin=yvals-datasum$se, ymax=yvals+datasum$se),
                    width=.2,position=position_dodge(.9))+
      ggtitle(graph.title2)+
      #scale_fill_manual(values=c("#0000CC", "#FF3333"))+
      ylab(y.title)+xlab(x.title)+ theme(legend.title=element_blank())
    if (for.presentation){
      g<-g+theme(axis.title.x=element_text(size=24))+theme(axis.title.y=element_text(size=24))+
      theme(axis.text.x=element_text(size=x.axis.text.size,angle=x.angle))+
      theme(title=element_text(size=36))+
      theme(legend.text = element_text(size = 24))+theme(axis.title.y=element_text(vjust=0.4))+theme(plot.title = element_text(vjust=2))+
      theme(legend.key.height=unit(0.8,"cm"))+theme(legend.key.width=unit(0.8,"cm"))
    }
    if (! missing(scale.fill)){
      g<-g+scale_fill_manual(values=scale.fill)
    }
    if (! missing(ranges)){
      g<-g+coord_cartesian(ylim = c(ranges$min[ranges$roi_name==paste(roi_temp[i])],ranges$max[ranges$roi_name==paste(roi_temp[i])]))
    }
    
    if (test){
    ##### significance testing
    levels_test<-unique(data[[x.value]])
    group_test<-unique(data[[group.value]])
    test.data.1<-temp[which(temp[[group.value]]==group_test[1]),]
    test.data.2<-temp[which(temp[[group.value]]==group_test[2]),]
    if (! missing(ranges)){
        max<-ranges$max[ranges$roi_name==paste(roi_temp[i])]
        min<-ranges$min[ranges$roi_name==paste(roi_temp[i])]
        range<-max-min
    } else {
        max<- max(yvals)+max(datasum$se)
        min<- min(yvals)
        range<-(max - min)*-.2
    }
    for (j in 1:length(levels_test)){
      #assign(paste(levels_test[i],"t",sep="."),t.test(
      #  test.data.1[[value]][which(test.data.1[[x.value]]==levels_test[i])],test.data.2[[value]][which(test.data.2[[x.value]]==levels_test[i])]))
      p<-t.test(test.data.1[[value]][which(test.data.1[[x.value]]==levels_test[j])],test.data.2[[value]][which(test.data.2[[x.value]]==levels_test[j])],paired=paired)$p.value
      if (!is.nan(p)){
      if (p < 0.05){
        g<-g+annotate("text", label = "*", x = j, y = max-range*0.1, size = 16, colour = "black")
        
        print(roi_temp[i])
        print(p)
        print("significant")
      }
      }
    }
    }
    
    
    
    print(g)
  }
}
  
 

  
  #  tp.t<-t.test(temp$value[which(temp$X=="tp" & temp$condition=="Smoking")],temp$value[which(temp$X=="tp" & temp$condition=="Abstinent")],paired=T)
  #  tn.t<-t.test(temp$value[which(temp$X=="tn" & temp$condition=="Smoking")],temp$value[which(temp$X=="tn" & temp$condition=="Abstinent")],paired=T)
  #  fp.t<-t.test(temp$value[which(temp$X=="fp" & temp$condition=="Smoking")],temp$value[which(temp$X=="fp" & temp$condition=="Abstinent")],paired=T)
  #  fn.t<-t.test(temp$value[which(temp$X=="fn" & temp$condition=="Smoking")],temp$value[which(temp$X=="fn" & temp$condition=="Abstinent")],paired=T)
  #  
  #  x<-max(datasum$value) #+0.1*(max(datasum$value)-min(datasum$value))
  #  
  #  if (tp.t$p.value < 0.05){
  #    g<-g+annotate("text", label = "*", x = 4, y = x, size = 16, colour = "black")
  #  }
  #  if (tn.t$p.value < 0.05){
  #    g<-g+annotate("text", label = "*", x = 3, y = x, size = 16, colour = "black")
  #  }
  #  if (fp.t$p.value < 0.05){
  #    g<-g+annotate("text", label = "*", x = 2, y = x, size = 16, colour = "black")
  #  }
  #  if (fn.t$p.value < 0.05){
  #    g<-g+annotate("text", label = "*", x = 1, y = x, size = 16, colour = "black")
  #  }
  #  
  #  print(g) 
