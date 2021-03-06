##' Stackplot: Produces stacked plots of CNV calls from multiple samples for a given locus.
##'
##' For each sample two tracks are plotted representing the Log R Ratio (LRR) and the B Allele Frequency (BAF).
##' @title StackPlot
##' @param Pos: Position of the loci to plot in the form chr21:1050000-1350000.
##' @param IDs: List of IDs to plot
##' @param PathRawData: The path to the raw data files contining LRR and BAF values to plot.
##' @param CNVs: Data frame containing the CNVs called on the samples.
##' @param Highlight: Position of a specific region to be highlighted, in the form chr21:1050000-1350000, default = NULL.
##' @param SNPList: Getting chromosome (chr) and position from another source than the RawFile - input should be the full path of the SNPList with columns: Name, Chr, and Position. Any positions from the RawFile will be erased. A PFB-column is also allowed but will be overwritten by the PFB-parameter or exchanged with 0.5, default = NULL.
##' @param key: Exchange the ID printed on the plot with a deidentified ID - requires that the CNV data frame contains a column called ID_deidentified, default = NA.
##' @param OutFolder: Path for saving outputfiles. Default is current folder
##' @param Files: Full path for each sample. You can get it using the command: Files <- list.files(path=PathRawData, pattern=Pattern, full.names=TRUE, recursive=FALSE). Then use Files=Files.
##' @param Pattern: File pattern in the raw data, default = "*".
##' @param Recursive: Logical, Should files matching patterns in subfolders be included, default = FALSE.
##' @return A png plot of the specified loci.
##' @author Johan Hilge Thygesen, Ida Elken Sønderby, Louise K. Hoeffding.
##' @source \url{http://biopsych.dk/iPsychCNV}
##' @export
##' @examples
##' mockCNV <- MockData(N=5, Type="Blood", Cores=1)
##' cnvs <- iPsychCNV(PathRawData=".", Cores=1, Pattern="^MockSample*", Skip=0)
##' StackPlot(Pos="chr21:28338230-46844965", IDs=unique(cnvs$ID), PathRawData=".", CNVs=cnvs, Highlight = "chr21:36653812-39117308")

StackPlot <- function(Pos, IDs, PathRawData, CNVs, Highlight = NULL, SNPList=NULL, key=NA, OutFolder=".", Files=NA, Pattern="",recursive=FALSE){
  suppressPackageStartupMessages(library(data.table))
  options(scipen=999) ## Disable scientific notation of positions

  ## Check and split position
  split.pos <- VerifyPos(Pos)
  chr <- split.pos[1]
  reg.start <- as.numeric(split.pos[2])
  reg.stop <- as.numeric(split.pos[3])

  ## Check IDs
  if(length(IDs) < 1) {
    stop("Please specify minimum ID")
  }

  ## Check highlight position if specified
  if (length(Highlight) > 0){
    split.pos <- VerifyPos(sub("--highlight ", "", Highlight))
    high.chr <- split.pos[1]
    high.start <- as.numeric(split.pos[2])
    high.stop <- as.numeric(split.pos[3])
    if(high.chr!=chr){
      stop("The highlight chromosome does not match the chromosome of the given position")
    }
  }

  ## Plot variables
  space <- 0.5
  box <- 1
  pr.page <- 5
  datestamp <- gsub(":",".",unlist(strsplit(as.character(Sys.time())," "))[2])
  if (!is.null(CNVs$locus[1])) {
    Locus <- as.character(CNVs$locus[1])
    basename <- paste(Locus, "_", "chr",chr,"-",reg.start,"-",reg.stop, sep="")
    } else {
  basename <- paste("chr",chr,"-",reg.start,"-",reg.stop, "_at_", datestamp, sep="")
    }
  xrange <- range(reg.start,reg.stop)
  yrange <- range(0, pr.page*(2*box+2*space))
  x <- 1 # start with id 1
  i <- 1 # we start with the 1 person on each page
  page.count <- 1 # start with page 1

  # Define Files
  if(is.na(Files[1]))
  {
    Files <- list.files(path=PathRawData, pattern=Pattern, full.names=TRUE, recursive=recursive)
  }


  ## Loop over each ID and plot away
  while(x <= length(IDs)){
    if(OutFolder!=".") {
      outname <- paste(OutFolder, basename, "_page-", page.count, sep="") }
    else {
      outname <- paste(basename, "_page-", page.count, sep="")
    }
    png(paste(outname, ".png", sep=""), width=1024, height=768) # can be convertedd to vertical page by switching width and height but requires adjustment of pr.page
    plot(xrange, yrange, type="n", yaxt='n', xaxt='n', xlab="", ylab="", main = Pos, cex.main=0.6)
    axis(3, at=axTicks(3),labels=formatC(axTicks(3), format="d", big.mark=','))
    topY <- max(yrange) - space
    ## CREATE a new plot after pr.page individuals have been plotted
    while(i <= pr.page) {
      # Find appropriate file for plotting
      if(is.na(IDs[x])) { # this deals with the issue that when using files, a line for each file is being printed: "No intensity files exists called")
        x <- 1 + x
        break
      } else {
          id.file <- Files[grep(paste("\\b", IDs[x], Pattern, "$", sep=""), Files)] # this should deal with similar filesnames, i.e 10 & 110
      }

      # Start to plot
      if(!file.exists(id.file)) {
        print(paste("NO intensity files exists called: ", id.file))
      }else{
        print(paste("Plotting",IDs[x]))

        id <- ReadSample(id.file, chr=chr, SNPList = SNPList)
        id <- id[which(id[,"Position"] > reg.start & id[,"Position"] < reg.stop), ]
        ## Trim intensities to a range between 0.5:-0.5
        if(any(id[,"Log.R.Ratio"] > 1, na.rm=T)) { id[which(id[,"Log.R.Ratio"] > 1), "Log.R.Ratio"] <- 1 }
        if(any(id[,"Log.R.Ratio"] < -1, na.rm=T)) { id[which(id[,"Log.R.Ratio"] < -1), "Log.R.Ratio"] <- -1 }
        ## Set all CN-markers to NA (as they all have the non-usable value of 2) ONLY REALLY FOR AFFY DATA
        if(any(id[,"B.Allele.Freq"] == 2, na.rm=T)) { id[which(id[,"B.Allele.Freq"] == 2), "B.Allele.Freq"] <- NA }
        ## Define plot area
        if(nrow(id) > 1){

          # If key is tagged, the ID in the plot will be a column called ID_deidentified
          if (!is.na(key)) {
            text(reg.stop-(reg.stop-reg.start)/2, topY + (space/3), paste("ID:",CNVs[CNVs$ID == IDs[x],]$ID_deidentified),lwd=1.5) ## Plot ID name
          } else {
            text(reg.stop-(reg.stop-reg.start)/2, topY + (space/3), paste("ID:",IDs[x]),lwd=1.5) ## Plot ID name
          }

          ## Plot Log R ratio and Intensity boxes
          rect(reg.start, topY-(2*box+(space/2)), reg.stop, topY-(box+(space/2)), col="#ffe2e2", border= F)
          rect(reg.start, topY-box, reg.stop, topY, col="#e5e2ff", border= F)


            ## Draw --Highlight box
          if(length(Highlight) > 0) {
            segments(high.start, topY-(2*box+(space/2)), high.start, topY, col="black",lwd=1.5) # Start
            segments(high.stop, topY-(2*box+(space/2)), high.stop, topY, col="black",lwd=1.5) # Stop
          }

            ## Draw all CNV Calls that match alias, chr and fall within region
          match <- CNVs[which(CNVs[,"ID"]==IDs[x] & CNVs[,"Chr"] == chr & CNVs[,"Start"] <= reg.stop & CNVs[,"Stop"] >= reg.start),]
          if(nrow(match)>0) {
            ## do not draw cnv boxes outside of plot
            if(any(match[,"Start"]<reg.start)) { match[which(match[,"Start"] < reg.start),"Start"] <- reg.start }
            if(any(match[,"Stop"]>reg.stop)) { match[which(match[,"Stop"] > reg.stop),"Stop"] <- reg.stop }
            for(j in 1:nrow(match)) {
              if(match[j,"CN"]>2){ rect(match[j,"Start"],topY-(2*box+(space/2)),match[j,"Stop"],topY,border="#2ef63c",lwd=2) }
              if(match[j,"CN"]<2){ rect(match[j,"Start"],topY-(2*box+(space/2)),match[j,"Stop"],topY,border="#ff0000",lwd=2) }
            }
          }
          ## Plot Log R ratio and Intensity points
          points(id[,"Position"], id[,"B.Allele.Freq"] + (topY-(1*box)), pch=20, cex=0.5, col = "darkblue")
          points(id[,"Position"], (id[,"Log.R.Ratio"]/2) + (topY-1.5*box-(space/2)), pch=20, cex=0.5, col = "darkred")
          ## Draw center line in boxs (x0, y0, x1, y1)
          segments(reg.start, topY-(box/2), reg.stop, topY-(box/2), col="black")
          segments(reg.start, (topY-1.5*box-(space/2)), reg.stop, (topY-1.5*box-(space/2)), col="black")
          ## Calc new Y-top spot
          topY <- topY-(2*box+1.5*space)

        }else{
          print(paste("No data available at this loci for",IDs[x]))
        }
      }
      ## increment
      i <- i + 1
      if(x <= length(IDs)){ x <- 1 + x}
      else{
        break
      }
    }
    page.count <- page.count + 1
    i <- 1 ## start with person 1 on the first page
    dev.off()  # gives one png per page
  }
}
