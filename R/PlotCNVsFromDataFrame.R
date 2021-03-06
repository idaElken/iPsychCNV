##' PlotCNVsFromDataFrame: Function to plot Log R Ratio (LRR) and B Allele Frequency (BAF) of CNVs from a data frame (DF).
##'
##' Specifically designed to handle noisy data from amplified DNA on phenylketonuria (PKU) cards. The function is a pipeline using many subfunctions.
##' @title PlotCNVsFromDataFrame
##' @param DF: Data frame with predicted CNVs for each sample, default = Unknown.
##' @param PathRawData: The path to the raw data files containing LRR and BAF values.
##' @param Cores: Number of cores used, default = 1.
##' @param Skip: Integer, the number of lines of the data file to be skipped before beginning to read the data, default = 0.
##' @param PlotPosition: Number of times the CNV size for each side of the CNV, default = 10.
##' @param Pattern: File pattern in the raw data, default = "*".
##' @param Recursive: Logical, Unknown, default = TRUE.
##' @param Dpi: Dots per inch, default = 300.
##' @param Files: Unknown, default = NA.
##' @param SNPList: Getting chromosome (Chr) and position from another source than the RawFile - input should be the full path of the SNPList with columns: Name, Chr, and Position. Any positions from the RawFile will be erased. A PFB-column is also allowed but will be overwritten by the PFB-parameter or exchanged with 0.5, default = NULL.
##' @param Key: Exchange the ID printed on the plot and in the name of file with a deidentified ID - requires that the DF contains a column called ID_deidentified, default = NA.
##' @param XAxisDefine: Position of a specific region to be plotted, in the form chr21:1050000-1350000, default = NULL.
##' @param OutFolder: Path for saving outputfiles, default is the current folder.
##' @return One BAF- and LRR-plot for each CNV.
##' @param LCR: List low copy repeat region region, list of SNPs that should be removed.
##' @param hg: Human genome version, default = hg19. For full range of possibilities, run ucscGenomes()$db {rtracklayer}, default=hg19
##' @author Marcelo Bertalan, Ida Elken Sønderby, Louise K. Hoeffding.
##' @source \url{http://biopsych.dk/iPsychCNV}
##' @export
##' @examples
##' # Creating CNVs from MockData & plotting
##' MockCNVs <- MockData(N=2, Type="Blood", Cores=10)
##' CNVs <- iPsychCNV(PathRawData=".", Pattern="^MockSample*", Skip=0)
##' CNVs.Good <- subset(CNVs, CN != 2) # keep only CNVs with CN = 0, 1, 3, 4.
##' PlotCNVsFromDataFrame(DF=CNVs.Good[1,], PathRawData=".", Cores=1, Skip=0, Pattern="^MockSamples*", key=NA, OutFolder="../", XAxisDefine = NULL)

PlotCNVsFromDataFrame <- function(DF, PathRawData=".", Cores=1, Skip=0, LCR=NULL, PlotPosition=10, Pattern="*",recursive=TRUE, dpi=300, Files=NA, SNPList=NULL, key=NA, OutFolder=".", XAxisDefine = NULL, Window=NA, hg="hg19") #
{
  library(ggplot2)
  library(ggbio) # For some reason ggplot2 2.0.2 is not working, probably conflict with other packages. Version 1.0.1 works.
  library(parallel)
  library(biovizBase)
  library(RColorBrewer)
  library(GenomicRanges)

  MustBeCol <- c("Chr", "Start", "Stop", "Length")
  if(sum(colnames(DF) %in% MustBeCol) != 4)
  {
    MissingCol <- setdiff(MustBeCol, colnames(DF)[colnames(DF) %in% MustBeCol])
    stop("You are missing: ", MissingCol, "\n")
  }

  # Load ideogram
  data(hg19IdeogramCyto)
  if(hg!="hg19")
  {
    IdeogramCyto <- getIdeogram(hg, cytoband = TRUE)
  }
  else
  {
    IdeogramCyto <- hg19IdeogramCyto
  }

  LocalFolder <- PathRawData
  if(is.na(Files))
  {
    Files <- list.files(path=PathRawData, pattern=Pattern, full.names=TRUE, recursive=recursive)
  }

  DF$UniqueID <- 1:nrow(DF)

  mclapply(DF$UniqueID, mc.cores=Cores, function(UID)
  {
    X <- subset(DF, UniqueID %in% UID)
    chr <- X$Chr
    ID <- X$ID
    UniqueID <- X$UniqueID
    cat(ID, "\n")

    CNVstart <- as.numeric(X$Start)
    CNVstop <- as.numeric(X$Stop)
    Size <- as.numeric(X$Length)
    CN <- X$CN
    SDCNV <- round(as.numeric(X$SDCNV), digits=2)
    NumSNP <- as.numeric(X$NumSNPs)

    ## Input XAxisDefine as defined start/stop for plot-area if specified
    if ( !is.null(XAxisDefine))
    {
      split.pos <- VerifyPos(sub("--highlight ", "", XAxisDefine))
      high.chr <- split.pos[1]
      high.start <- as.numeric(split.pos[2])
      high.stop <- as.numeric(split.pos[3])
      Start <- high.start # change start and stop-position to position of XAxisDefine
      Stop <- high.stop # change stop-position to that of XAxisDefine
      if(high.chr!=chr) # check that match between XAxisDefine-Chr & chr of CNV
      {
        stop("The XAxisDefine chromosome does not match the chromosome of the given position")
      }
      if(high.start>CNVstart | high.stop<CNVstop) # check that XAxisDefine Position covers CNV
      {
        stop("The XAxisDefine start and stop does not cover the range of the CNV")
      }
    }
    else
    {
      # Start & Stop-positions of plot
      Start <- CNVstart - (Size*PlotPosition)
      Stop <-  CNVstop + (Size*PlotPosition)

     }

    # Defining Window-size
    if(is.na(Window))
    {
      Window <- round(sqrt(NumSNP))
    }
    if(Window < 5){ Window <- 5 }
    if(Window > 35){ Window <- 35 }

    ## Naming output-file

    # based on key or not
    if (!is.na(key))  # if want a different ID from the genetic ID in the plot
    {
      ID_deidentified <- X$ID_deidentified  # Added this to get ID_deidentified
      NewName <- paste(ID_deidentified, "_chr", chr, "_", CNVstart, "-", CNVstop, sep="", collapse="")
    }
    else
    {
      NewName <- paste(ID,"_chr", chr, "_", CNVstart, "-", CNVstop, sep="", collapse="")
    }

    # based on OutFolder or not
    if(OutFolder!=".")
    {
      OutPlotfile <- paste(OutFolder, NewName, "_plot.png", sep="", collapse="")
    }
    else
    {
      OutPlotfile <- paste(NewName, "plot.png", sep="_", collapse="")
    }

    # Reading sample file
    #RawFile <- paste(PathRawData, ID, sep="", collapse="")
    # RawFile <- Files[grep(ID, Files)]
      RawFile <- Files[grep(paste("\\b", ID, Pattern, "$", sep = ""), Files)] # this should deal with similar filesnames, i.e 10 & 110

    cat("File: ", RawFile,"\n")
    sample <- ReadSample(RawFile, skip=Skip, SNPList=SNPList, LCR=LCR)

    ## Set all CN-markers to NA (as they all have the non-usable value of 2) ONLY REALLY FOR AFFY DATA
    if(any(sample[,"B.Allele.Freq"] == 2, na.rm=T)) { sample[which(sample[,"B.Allele.Freq"] == 2), "B.Allele.Freq"] <- NA }

    red <- subset(sample,Chr==chr) # select SNPs from rawfile in Chr of interest
    red <- subset(red, Position > Start & Position < Stop) # select SNPs from rawfile that is within the plotted area
    red2 <- red[with(red, order(Position)),] # order selected SNPs by Position

    Mean <- SlideWindowMean(red2$Log.R.Ratio, Window)
    red2$Mean <- Mean

    # Ideogram
#    data(hg19IdeogramCyto,package="biovizBase")
    CHR <- paste("chr", chr, collapse="", sep="")
    p3 <- plotIdeogram(IdeogramCyto,CHR,cytoband=TRUE,xlabel=TRUE, aspect.ratio = 1/85, alpha = 0.3, zoom.region=c(CNVstart, CNVstop)) +
      xlim(GRanges(CHR,IRanges(Start,Stop)))

    # Colors
    Colors = brewer.pal(7,"Set1")

    # B.Allele
    rect2 <- data.frame (xmin=CNVstart, xmax=CNVstop, ymin=0, ymax=1) # CNV position

    # Info for breaks, to always have 10 breaks.
    BY <- round((max(red2$Position) - min(red2$Position))/10)

    # B Allele Freq
    p1 <- ggplot() + geom_point(data=red2, aes(x=Position, y = B.Allele.Freq, col="B.Allele.Freq"), size=1) +
    geom_rect(data=rect2, aes(xmin=xmin, xmax=xmax, ymin=ymin, ymax=ymax, col="CNV region"), alpha=0.2, inherit.aes = FALSE) +
    theme(legend.title=element_blank()) + scale_color_manual(values = c(Colors[2:4]) ) +
    scale_x_continuous(breaks = round(seq(min(red2$Position), max(red2$Position), by = BY),1))

    # LogRRatio
    p2 <- ggplot() + geom_point(data=red2, aes(x=Position, y=Log.R.Ratio, col="Log.R.Ratio"), alpha = 0.6, size=1)  +
      geom_line(data=red2, aes(x=Position, y = Mean, col="Mean"), size = 0.5) + # Mean of signal line
      ylim(-1, 1) + # set y-axis
      theme(legend.title=element_blank()) +
      scale_color_manual(values = c(Colors[1], "black")) +  # black color
      scale_x_continuous(labels=format_si(), # this sets the axis label to K, M for 1000, 1000000 etc...
                         breaks = round(seq(min(red2$Position), max(red2$Position), by = BY),1)) # this gives a distance of 500,000 between ticks on x-axis

    # Title printed for plot
    if (!is.na(key))  # if want a different ID from the genetic ID in the plot
    {
      Title <- paste("CN: ", CN, "   Size: ", prettyNum(Size, big.mark=",",scientific=FALSE), "   SNPs: ", NumSNP, "   Sample: ", ID_deidentified, sep="", collapse="")
    }
    else
    {
      Title <- paste("CN: ", CN, "   Size: ", prettyNum(Size, big.mark=",",scientific=FALSE), "   SNPs: ", NumSNP, "   Sample: ", ID, sep="", collapse="")
    }
    Plot <- tracks(p3, p1,p2, main=Title, heights=c(3, 5,5))
    ggsave(OutPlotfile, plot=Plot, height=5, width=10, dpi=dpi)

  })
}
