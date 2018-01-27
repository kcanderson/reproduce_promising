source("https://bioconductor.org/biocLite.R")
biocLite("org.Hs.eg.db")
biocLite("annotate")

install.packages(c("igraph", "stringr", "plyr", "httr", "jsonlite"), repos = "http://cran.us.r-project.org")
install.packages("prix_fixe/PrixFixe_0.1-2.tar.gz", repos = NULL, type = "source")
