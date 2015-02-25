EvaluateMockResults <- function(MockCNVs, df)
{
	library(pROC)
	Eval <- apply(MockCNVs, 1, function(X)
	{
		StartM <- as.numeric(X["Start"])
		StopM <- as.numeric(X["Stop"])
		IDM <- as.character(X["ID"])
		ChrM <- as.numeric(X["Chr"])
		LengthM <- as.numeric(X["Length"])
		NumSNPsM <- as.numeric(X["NumSNPs"])
		CNVID <- gsub(" ", "", X["CNVID"])
		CNM <- as.numeric(X["CN"])

		if(CNM == 2){ CNV.Present=0 }else{ CNV.Present=1 }
		# From df predition
 		res <- subset(df, Chr == ChrM & Start <= StopM & Stop >= StartM & ID %in% IDM)
		NumCNVs <- nrow(res)
		if(NumCNVs > 1)
		{
			res <- subset(res, Length == max(res$Length))	
			if(nrow(res) > 1){ res <- res[1,]}			
		}

		CNVID2 <- res$CNVID
		CN2 <- as.numeric(res$CN)
		cat(nrow(res), " ", CN2, "\r") 


		if(NumCNVs == 0)
		{
			CNV.Predicted <- 0
			PredictedByOverlap <- 0
			OverlapLenghM <- 0
			OverlapSNP <-0
			CNVID2 <- NA
			CN2 <- 2
			
		}
		else
		{	
			StartO <- max(c(res$Start, StartM))
			StopO <- min(c(res$Stop, StopM))
			LengthO <- StopO - StartO

			OverlapLenghM <- ((LengthO/LengthM)*100)
			OverlapSNP <- ((res$NumSNPs/NumSNPsM)*100)

			if(CNM == 2)
			{
				res2 <- subset(df, Chr == ChrM & Start > StartM & Stop < StopM & ID %in% IDM) # If is a non-CNV region, than prediction need to be inside.
				if(nrow(res2) > 0)
				{
					CNV.Predicted = 1
					PredictedByOverlap <- 1		# It doesn't matter the overlap the prediction is in a non-CNV region.
				}
				else
				{
					CNV.Predicted = 0
					PredictedByOverlap <- 0
				}
			}
			else
			{
				if(CNM == CN2)
				{	
					CNV.Predicted = 1 
					if(OverlapLenghM > 80 & OverlapLenghM < 120)
					{ 
						PredictedByOverlap <- 1 
					}
					else
					{
						PredictedByOverlap <- 0 	# CNV predicted is far from what it should be
					}
				}
				else						# There is a prediction but is not correct
				{ 
					CNV.Predicted = 0 
					PredictedByOverlap <- 0
				} 
			}
		}

		df2 <- data.frame(CNV.Present=CNV.Present, CNV.Predicted=CNV.Predicted, Overlap.Length=OverlapLenghM, Overlap.SNP=OverlapSNP, CNVID.Mock=CNVID, CNVID.Pred=CNVID2, CN.Pred=CN2, NumCNVs = NumCNVs, PredictedByOverlap=PredictedByOverlap, stringsAsFactors=FALSE)
		return(df2)
	})
	Eval <- MatrixOrList2df(Eval)
	df3 <- cbind(Eval, MockCNVs)
	return(df3)
}