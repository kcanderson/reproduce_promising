library(org.Hs.eg.db)
library(annotate)
library(PrixFixe)

## Helper functions
readGMT <- function(gmt.filename) {
    lines <- strsplit(scan(file = gmt.filename, what = "", sep = "\n"), "\t")
    not.empty <- sapply(lines, function (l) { length(l) > 2})
    lines <- lines[not.empty]
    genesets <- lapply(lines, function (line) {
        line[3:max(3, length(line))]
    })
    names(genesets) <- lapply(lines, function (line) {
        line[1]
    })
    
    genesets
}
makeNCBIGene <- function(gene.symbols) {
    ncbi.vals <- mget(x=gene.symbols, envir=org.Hs.egALIAS2EG, ifnotfound = NA)
    ncbi.vals <- unlist(lapply(ncbi.vals, function (x) { x[1] }))
    ncbi.vals <- paste("NCBI_Gene:", ncbi.vals, sep = "")
    ncbi.vals
}
ncbizeInteractions <- function(interactions) {
    interactions[,1] = makeNCBIGene(interactions[,1])
    interactions[,2] = makeNCBIGene(interactions[,2])
    interactions
}
getCandidateEdges <- function(interactions, genesets) {
    all.genes <- unlist(genesets)
    interactions[((interactions[,1] %in% all.genes) & (interactions[,2] %in% all.genes)),]
}
makeHGNC <- function(ncbi.ids) {
    ncbi.ids <- substring(ncbi.ids, 11)
    hgnc.names <- mget(x = ncbi.ids, org.Hs.egSYMBOL, ifnotfound = NA)
    unlist(lapply(hgnc.names, function (x) { x[1] }))
}

## Pull out command-line args and do needful
args <- commandArgs(TRUE)
gmt.filename <- args[1]
interactions.filename <- args[2]
output.filename <- args[3]

## Read genesets from GMT file
genesets <- readGMT(args[1])

## Read interactions
edges <- read.csv(file=interactions.filename, sep="\t", stringsAsFactors=FALSE)

## PERFORMANCE IMPROVEMENT: Subset to only those
##  edges containing genes from genesets
edges <- getCandidateEdges(edges, genesets)
dim(edges)
head(edges)

## Transform HGNC symbols to NCBI IDs
genesets <- lapply(genesets, function (gset) {
    gs <- makeNCBIGene(gset)
    ## Remove NAs (PrixFixe is very picky)
    gs <- gs[(gs != "NCBI_Gene:NA")]
    gs
})
edges <- ncbizeInteractions(edges)

## Remove edges that didn't map to NCBI ids
edges <- edges[edges[,1] != "NCBI_Gene:NA" & edges[,2] != "NCBI_Gene:NA",]

## Setup PrixFixe
pf <- GPF$PF$new(genesets, edges)

## Run PF
pf.results <- GPF$GA$scoreVertices(GPF$GA$run(pf))

## Output in appropriate format
colnames(pf.results) <- c("locus", "gene", "score", "scaled_score")
head(pf.results)
pf.results$gene <- makeHGNC(pf.results$gene)
pf.results <- pf.results[order(pf.results$score, decreasing=TRUE),]

write.table(pf.results, file = output.filename, sep = "\t", row.names = FALSE, quote = FALSE)

