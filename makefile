
ANNOTATIONS_DIR := annotations
ANNOTATIONS := $(ANNOTATIONS_DIR)/Homo_sapiens.GRCh37.70.with.entrezid.gtf
DEP_DIR := dependencies
HELPER_DIR := $(DEP_DIR)/promising_helper
UBERJAR := $(HELPER_DIR)/target/promising_helper-0.1.0-SNAPSHOT-standalone.jar
PROMISING_BIN := $(DEP_DIR)/PROMISING/src/promising
BASE_CMD := java -jar $(UBERJAR)
SSNPS_DIR := snps_source
SNP_CASES := $(patsubst $(SSNPS_DIR)/%.tsv,%,$(wildcard $(SSNPS_DIR)/*.tsv))
.SECONDARY:

all: validation

clean: clean_snps clean_gsets

# Dependencies
$(UBERJAR) $(PROMSING_BIN) $(ANNOTATIONS):
	bash install.sh

# SNPs
DSNPS_DIR := snps_derived
TRAITS_CMD := $(BASE_CMD) select-traits
SNPS_CMD := $(BASE_CMD) snps

$(SSNPS_DIR)/%_traits.txt: $(SSNPS_DIR)/%.tsv $(UBERJAR)
	$(TRAITS_CMD) -i $< -o $@

$(DSNPS_DIR)/%.txt: $(SSNPS_DIR)/%_traits.txt $(SSNPS_DIR)/%.tsv $(UBERJAR)
	$(SNPS_CMD) -t $< -i $(@:$(DSNPS_DIR)/%.txt=$(SSNPS_DIR)/%.tsv) -o $@

snps: $(SNP_CASES:%=$(SSNPS_DIR)/%_traits.txt) $(SNP_CASES:%=$(DSNPS_DIR)/%.txt)

clean_snps:
	@rm $(SNP_CASES:%=$(SSNPS_DIR)/%_traits.txt) $(SNP_CASES:%=$(DSNPS_DIR)/%.txt)

# Genesets
GENESETS_DIR := genesets
GENESETS_CMD := $(BASE_CMD) genesets
FLANK := 50000

$(GENESETS_DIR)/%.gmt: $(DSNPS_DIR)/%.txt $(UBERJAR)
	$(GENESETS_CMD) -i $< -o $@ -f $(FLANK)

gsets: $(SNP_CASES:%=$(GENESETS_DIR)/%.gmt)

clean_gsets:
	@rm $(SNP_CASES:%=$(GENESETS_DIR)/%.gmt)

# Derived networks
SNET_DIR := networks_source
DNET_DIR := networks_derived
DNET_CMD := $(BASE_CMD) network
STRING_NET := $(DNET_DIR)/string.tsv
STRINGNOTM_NET := $(DNET_DIR)/stringnotm.tsv
PF_NET := $(DNET_DIR)/pf.tsv
NETWORK_CASES = stringnotm string pf

$(STRING_NET): $(SNET_DIR)/9606.protein.links.detailed.v10.txt $(UBERJAR) $(ANNOTAIONS)
	$(DNET_CMD) -t string -m -s 0.15 -a $(ANNOTATIONS) -i $< -o $@

$(STRINGNOTM_NET): $(SNET_DIR)/9606.protein.links.detailed.v10.txt $(UBERJAR) $(ANNOTATIONS)
	$(DNET_CMD) -t string -s 0.15 -a $(ANNOTATIONS) -i $< -o $@

$(PF_NET): $(SNET_DIR)/main_FAN.csv $(UBERJAR) $(ANNOTATIONS)
	$(DNET_CMD) -t pf -a $(ANNOTATIONS) -i $< -o $@

networks: $(NETWORK_CASES:%=$(DNET_DIR)/%.tsv)
#networks: $(DNET_DIR)/stringnotm.tsv $(DNET_DIR)/string.tsv $(DNET_DIR)/pf.tsv

# Kernels
KERNEL_DIR := kernels
#DNETS := $(shell ls $(DNET_DIR)/*.tsv)
#DNETS := $(wildcard $(DNET_DIR)/*.tsv)
KERNEL_CMD := java -Xmx24g -jar $(UBERJAR) kernel
ALPHA := 0.001

$(KERNEL_DIR)/%_reglap.mat: $(DNET_DIR)/%.tsv $(UBERJAR)
	$(KERNEL_CMD) -a $(ALPHA) -i $< -o $@

kernels: $(NETWORK_CASES:%=$(KERNEL_DIR)/%_reglap.mat)
#kernels: $(DNETS:$(DNET_DIR)/%.tsv=$(KERNEL_DIR)/%_reglap.mat)

# Results
GENESET_CASES := $(patsubst $(GENESETS_DIR)/%.gmt,%,$(wildcard $(GENESETS_DIR)/*.gmt))
ALL_CASES := $(SNP_CASES) $(GENESET_CASES)
ALL_CASES := $(sort $(ALL_CASES))

## PROMISING
RESULTS_DIR := results
PROMISING := promising
P_RESULTS_DIR := $(RESULTS_DIR)/$(PROMISING)
PVAL_ITERATIONS := 50000
KERNELS = $(NETWORKS:%=%_reglap)
PROMISING_CMD := $(PROMISING_BIN) -p $(PVAL_ITERATIONS)

$(P_RESULTS_DIR):
	mkdir -p $(RESULTS_DIR)/$(PROMISING)

## This secondary expansion stuff is gnarly...
.SECONDEXPANSION:
$(P_RESULTS_DIR)/%.tsv: $(PROMISING_BIN) $(P_RESULTS_DIR) $(KERNEL_DIR)/$$(shell echo $$(subst .tsv,,$$(@F)) | sed 's/^[^_]*_//g').mat $(GENESETS_DIR)/$$(word 1,$$(subst _, ,$$(@F))).gmt
	mkdir -p $(@D)
	$(PROMISING_CMD) -m $(word 3,$^) -g $(word 4,$^) -o $@

promising_results: $$(foreach k, $$(KERNELS), $$(foreach c, $$(ALL_CASES), $(RESULTS_DIR)/$(PROMISING)/$$(c)_$$(k).tsv))

## PF
PF_RESULTS_DIR := $(RESULTS_DIR)/pf
PF_CMD := Rscript $(DEP_DIR)/prix_fixe/run_pf.r
NETWORK_PATHS := $(wildcard $(DNET_DIR)/*.tsv)
NETWORKS := $(NETWORK_PATHS:$(DNET_DIR)/%.tsv=%)

$(PF_RESULTS_DIR):
	mkdir -p $(PF_RESULTS_DIR)

$(PF_RESULTS_DIR)/%.tsv: $(PF_RESULTS_DIR) $(GENESETS_DIR)/$$(word 1,$$(subst _, ,$$(@F))).gmt $(DNET_DIR)/$$(shell echo $$(@F) | sed "s/^[^_]*_//g")
	mkdir -p $(@D)
	$(PF_CMD) $(word 2,$^) $(word 3,$^) $@

pf_results: $$(foreach n, $$(NETWORKS), $$(foreach c, $$(ALL_CASES), $(PF_RESULTS_DIR)/$$(c)_$$(n).tsv))

all_results: promising_results pf_results

# MONARCH known genes
SMONARCH_DIR := monarch_source
DMONARCH_DIR := monarch_derived
MONARCH_CMD := $(BASE_CMD) monarch
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
