## ---- include=F----------------------------------------------------------
library(MetMSLine)

## ---- collapse=TRUE------------------------------------------------------
# file path example peakTable in comma delimited csv file 
# (see ?example_Exp_MS1features for details).
peakTable <- system.file("extdata", "MS1features_example.csv", package = "MetMSLine")
peakTable <- read.csv(peakTable, header=T, stringsAsFactors=F)


# load co-variates table in comma delimited csv file
coVariates <- system.file("extdata", "coVariates.csv", package = "MetMSLine")
coVariates <- read.csv(coVariates, header=T)
# observation names (i.e. sample names)
obsNames <- colnames(peakTable)[grep('ACN_|MeOH_', colnames(peakTable))]

# zero fill
peakTable <- zeroFill(peakTable, obsNames)

# Normalize (median fold change/ probabilistic quotient), total ion signal 
#  also available ?signNorm
peakTable <- signNorm(peakTable, obsNames, method="medFC")

# data deconvolution based on retention time and interfeature correlation
# calculation of weighted mean (see ?weigthed.mean) within each pseudospectral 
# cluster (i.e. the sum of mass spectral intensities across all samples are used 
#          to weight the contribution of each feature to the average).
wMeanPeakTable <- rtCorrClust(peakTable, obsNames, rtThresh=2, corrThresh=0.9, 
                              minFeat=1)

# extract weighted mean pseudospectra table
wMeanPspec <- wMeanPeakTable$wMeanPspec

# log transform (base 2)
wMeanPspec <- logTrans(wMeanPspec, obsNames, base=2)



## ------------------------------------------------------------------------

# add dummy blank to illustrate pca outlier detection
wMeanPspec$blank_1 <- 0.0001
# observation names (i.e. sample names)
obsNames <- colnames(wMeanPspec)[grep('ACN_|MeOH_|blank_', colnames(wMeanPspec))]

#  PCA projection using pca of pcaMethods and automatic outlier removal based
#  on proportional expansion of the Hotellings T2 ellipse
pcaOutResults <- pcaOutId(wMeanPspec, obsNames, cv="q2", outTol=1.05, 
                          scale="pareto")

# Plot PCA displaying any outliers and expanded Hotelling's ellipse, colour according
# to any potential outliers detected. function modified from pcaMethods ?plotPcs.
plotPcsEx(pcaOutResults$pcaResults[[1]]$pcaResult, 
          pcaOutResults$pcaResults[[1]]$exHotEllipse, type="scores", 
          col=pcaOutResults$pcaResults[[1]]$possOut+2)

# plot second PCA model iteration after outlier removal
plotPcsEx(pcaOutResults$pcaResults[[2]]$pcaResult, 
          pcaOutResults$pcaResults[[2]]$exHotEllipse, type="scores", 
          col=pcaOutResults$pcaResults[[2]]$possOut+2)

# show PCA results iteration 2
pcaOutResults$pcaResults[[2]]$pcaResult
# show Q2 cross-validation statistic
pcaOutResults$pcaResults[[2]]$pcaResult@cvstat

# label by extraction type using co-variates table
plotPcsEx(pcaOutResults$pcaResults[[2]]$pcaResult, 
          pcaOutResults$pcaResults[[2]]$exHotEllipse, type="scores", 
          col=as.numeric(as.factor(coVariates$extractionType)) + 2)

# Automatically identify potential cluster membership given the table of co-variates
finalPca <- pcaOutResults$pcaResults[[length(pcaOutResults$pcaResults)]]$pcaResult
clustIdentity <- pcaClustId(finalPca, coVarTable=coVariates)
# plot pam cluster model (partioning around the medoids), minimisation of 
# dissimilarities.
plot(cluster::pam(finalPca@scores, clustIdentity[[1]]$nc))



## ------------------------------------------------------------------------

# outliers removed peak table from pcaOutId output
outRemPeakTable <- pcaOutResults$outRem
obsNames <- colnames(outRemPeakTable)[grep('ACN_|MeOH_', colnames(outRemPeakTable))]

# automatic univariate statistical method selection and mean/median fold calculation
statResult <- coVarTypeStat(outRemPeakTable, obsNames, 
                            coVariate=coVariates$extractionType, 
                            Logged=T, base=2)
# volcanoPlot  
volcanoPlot(log2(statResult[[5]]$FoldChange), statResult[[5]]$p.value)


