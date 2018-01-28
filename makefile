
ANNOTATIONS_DIR := annotations
ANNOTATIONS := $(ANNOTATIONS_DIR)/Homo_sapiens.GRCh37.70.with.entrezid.gtf
DEP_DIR := dependencies
HELPER_DIR := $(DEP_DIR)/promising_helper
UBERJAR := $(HELPER_DIR)/target/promising_helper-0.1.0-SNAPSHOT-standalone.jar
PROMISING_BIN := $(DEP_DIR)/PROMISING/src/promising
BASE_CMD := java -jar $(UBERJAR)
SSNPS_DIR := snps_source

all: validation

# Dependencies
$(UBERJAR) $(PROMSING_BIN) $(ANNOTATIONS):
	bash install.sh

# SNPs
#SSNPS := $(shell ls -1 $(SSNPS_DIR)/*.tsv)
SSNPS := $(wildcard $(SSNPS_DIR)/*.tsv)
DSNPS_DIR := snps_derived
TRAITS_CMD := $(BASE_CMD) select-traits
SNPS_CMD := $(BASE_CMD) snps

$(SSNPS_DIR)/%_traits.txt: $(SSNPS_DIR)/%.tsv $(UBERJAR)
	$(TRAITS_CMD) -i $< -o $@

$(DSNPS_DIR)/%.txt: $(SSNPS_DIR)/%_traits.txt $(SSNPS_DIR)/%.tsv $(UBERJAR)
	$(SNPS_CMD) -t $< -i $(@:$(DSNPS_DIR)/%.txt=$(SSNPS_DIR)/%.tsv) -o $@

snps: $(SSNPS:%.tsv=%_traits.txt) $(SSNPS:$(SSNPS_DIR)/%.tsv=$(DSNPS_DIR)/%.txt)

# Genesets
#DSNP_FILES := $(shell ls $(DSNPS_DIR)/*.txt)
DSNP_FILES := $(wildcard $(DSNPS_DIR)/*.txt)
CASES := $(DSNP_FILES:$(DSNPS_DIR)/%.txt=%)
GENESETS_DIR := genesets
GENESETS_CMD := $(BASE_CMD) genesets
FLANK := 50000

$(GENESETS_DIR)/%.gmt: $(DSNPS_DIR)/%.txt $(UBERJAR)
	$(GENESETS_CMD) -i $< -o $@ -f $(FLANK)

genesets: $(CASES:%=$(GENESETS_DIR)/%.gmt)

# Derived networks
SNET_DIR := networks_source
DNET_DIR := networks_derived
DNET_CMD := $(BASE_CMD) network
STRING_NET := $(DNET_DIR)/string.tsv
STRINGNOTM_NET := $(DNET_DIR)/stringnotm.tsv
PF_NET := $(DNET_DIR)/pf.tsv

$(STRING_NET): $(SNET_DIR)/9606.protein.links.detailed.v10.txt $(UBERJAR) $(ANNOTAIONS)
	$(DNET_CMD) -t string -m -s 0.15 -a $(ANNOTATIONS) -i $< -o $@

$(STRINGNOTM_NET): $(SNET_DIR)/9606.protein.links.detailed.v10.txt $(UBERJAR) $(ANNOTATIONS)
	$(DNET_CMD) -t string -s 0.15 -a $(ANNOTATIONS) -i $< -o $@

$(PF_NET): $(SNET_DIR)/main_FAN.csv $(UBERJAR) $(ANNOTATIONS)
	$(DNET_CMD) -t pf -a $(ANNOTATIONS) -i $< -o $@

networks: $(DNET_DIR)/stringnotm.tsv $(DNET_DIR)/string.tsv $(DNET_DIR)/pf.tsv

# Kernels
KERNEL_DIR := kernels
#DNETS := $(shell ls $(DNET_DIR)/*.tsv)
DNETS := $(wildcard $(DNET_DIR)/*.tsv)
KERNEL_CMD := java -Xmx24g -jar $(UBERJAR) kernel
ALPHA := 0.001

$(KERNEL_DIR)/%_reglap.mat: $(DNET_DIR)/%.tsv $(UBERJAR)
	$(KERNEL_CMD) -a $(ALPHA) -i $< -o $@

kernels: networks $(DNETS:$(DNET_DIR)/%.tsv=$(KERNEL_DIR)/%_reglap.mat)

# Results
## PROMISING
RESULTS_DIR := results
PROMISING := promising
P_RESULTS_DIR := $(RESULTS_DIR)/$(PROMISING)
PVAL_ITERATIONS := 10000
MAT_FILES := $(wildcard $(KERNEL_DIR)/*.mat)
KERNELS := $(MAT_FILES:$(KERNEL_DIR)/%.mat=%)
GENESET_FILES := $(wildcard $(GENESETS_DIR)/*.gmt)
GENESETS := $(GENESET_FILES:$(GENESETS_DIR)/%=%)
PROMISING_CMD := $(PROMISING_BIN) -p $(PVAL_ITERATIONS)

$(P_RESULTS_DIR):
	mkdir -p $(RESULTS_DIR)/$(PROMISING)

$(P_RESULTS_DIR)/%.tsv: $(PROMISING_BIN) $(P_RESULTS_DIR)
	mkdir -p $(@D)
	$(PROMISING_CMD) -m $(KERNEL_DIR)/$(shell echo $(@F:%.tsv=%) | sed 's/^[^_]*_//g').mat -g $(GENESETS_DIR)/$(word 1,$(subst _, ,$(@F))).gmt -o $@

promising_results: genesets kernels $(foreach k, $(KERNELS), $(foreach g, $(GENESETS), $(RESULTS_DIR)/$(PROMISING)/$(g:%.gmt=%)_$(k).tsv))

## PF
PF_RESULTS_DIR := $(RESULTS_DIR)/pf
PF_CMD := Rscript $(DEP_DIR)/prix_fixe/run_pf.r
NETWORK_PATHS := $(wildcard $(DNET_DIR)/*.tsv)
NETWORKS := $(NETWORK_PATHS:$(DNET_DIR)/%.tsv=%)

$(PF_RESULTS_DIR):
	mkdir -p $(PF_RESULTS_DIR)

$(PF_RESULTS_DIR)/%.tsv: $(PF_RESULTS_DIR)
	mkdir -p $(@D)
	$(PF_CMD) $(GENESETS_DIR)/$(word 1,$(subst _, ,$(@F))).gmt $(DNET_DIR)/$(shell echo $(@F:%.tsv=%) | sed "s/^[^_]*_//g").tsv $@

pf_results: genesets networks $(foreach n, $(NETWORKS), $(foreach g, $(GENESETS), $(PF_RESULTS_DIR)/$(g:%.gmt=%)_$(n).tsv))

# $(PF_RESULTS_DIR)/string/%.tsv: $(PF_RESULTS_DIR) $(GENESETS_DIR)/%.gmt
# 	mkdir -p $(@D)
# 	$(PF_CMD) $(word 2,$^) $(STRING_NET) $@

# $(PF_RESULTS_DIR)/stringnotm/%.tsv: $(PF_RESULTS_DIR) $(GENESETS_DIR)/%.gmt
# 	mkdir -p $(@D)
# 	$(PF_CMD) $(word 2,$^) $(STRING_NOTM_NET) $@

# $(PF_RESULTS_DIR)/pf/%.tsv: $(PF_RESULTS_DIR) $(GENESETS_DIR)/%.gmt
# 	mkdir -p $(@D)
# 	$(PF_CMD) $(word 2,$^) $(PF_NET) $@

#pf_results: $(CASES:%=$(PF_RESULTS_DIR)/string/%.tsv) $(CASES:%=$(PF_RESULTS_DIR)/stringnotm/%.tsv) $(CASES:%=$(PF_RESULTS_DIR)/pf/%.tsv)

results: promising_results pf_results

# MONARCH known genes
SMONARCH_DIR := monarch_source
DMONARCH_DIR := monarch_derived
MONARCH_CMD := $(BASE_CMD) monarch
#SMONARCH_FILES := $(shell ls $(SMONARCH_DIR)/*.tsv)
SMONARCH_FILES := $(wildcard $(SMONARCH_DIR)/*.tsv)
MCASES := $(SMONARCH_FILES:$(SMONARCH_DIR)/%.tsv=%)

$(DMONARCH_DIR)/%.txt: $(SMONARCH_DIR)/%.tsv $(UBERJAR)
	$(MONARCH_CMD) -i $< -o $@

monarch: $(MCASES:%=$(DMONARCH_DIR)/%.txt)

# Validation
VALIDATION_CMD := java -jar $(UBERJAR) validate
VALIDATION_DIR := validation
VALIDATION_FILENAME := validation.tsv
VALIDATION_FILEPATH := $(VALIDATION_DIR)/$(VALIDATION_FILENAME)
PVAL_ITERATIONS_VAL := 5000

$(VALIDATION_FILEPATH): $(wildcard $(RESULTS_DIR)/*/*/*.tsv)
	$(VALIDATION_CMD) -r $(RESULTS_DIR) -t $(DMONARCH_DIR) -o $@ -p $(PVAL_ITERATIONS_VAL)

validation: monarch results $(VALIDATION_FILEPATH)

# Validation: GSEA curves
