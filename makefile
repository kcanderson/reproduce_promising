
# Don't remove intermediary files
ANNOTATIONS_DIR := annotations
ANNOTATIONS := $(shell ls $(ANNOTATIONS_DIR)/*.gtf)
DEP_DIR := dependencies
HELPER_DIR := $(DEP_DIR)/promising_helper
UBERJAR := $(shell ls $(HELPER_DIR)/target/*-standalone.jar)
BASE_CMD := java -jar $(UBERJAR)

SSNPS_DIR := snps_source

# SNPs
SSNPS := $(shell ls -1 $(SSNPS_DIR)/*.tsv)
DSNPS_DIR := snps_derived
TRAITS_CMD := $(BASE_CMD) select-traits
SNPS_CMD := $(BASE_CMD) snps

$(SSNPS_DIR)/%_traits.txt: $(SSNPS_DIR)/%.tsv
	$(TRAITS_CMD) -i $< -o $@

$(DSNPS_DIR)/%.txt: $(SSNPS_DIR)/%_traits.txt $(SSNPS_DIR)/%.tsv
	$(SNPS_CMD) -t $< -i $(@:$(DSNPS_DIR)/%.txt=$(SSNPS_DIR)/%.tsv) -o $@

snps: $(SSNPS:%.tsv=%_traits.txt) $(SSNPS:$(SSNPS_DIR)/%.tsv=$(DSNPS_DIR)/%.txt)

# Genesets
DSNP_FILES := $(shell ls $(DSNPS_DIR)/*.txt)
CASES := $(DSNP_FILES:$(DSNPS_DIR)/%.txt=%)
GENESETS_DIR := genesets
GENESETS_CMD := java -jar $(UBERJAR) genesets
FLANK := 50000

$(GENESETS_DIR)/%.gmt: $(DSNPS_DIR)/%.txt
	$(GENESETS_CMD) -i $< -o $@ -f $(FLANK)

genesets: $(CASES:%=$(GENESETS_DIR)/%.gmt)

# Derived networks
SNET_DIR := networks_source
DNET_DIR := networks_derived
DNET_CMD := $(BASE_CMD) network
STRING_NET := $(DNET_DIR)/string.tsv
STRING_NOTM_NET := $(DNET_DIR)/string_notm.tsv
PF_NET := $(DNET_DIR)/pf.tsv

$(STRING_NET): $(SNET_DIR)/9606.protein.links.detailed.v10.txt
	$(DNET_CMD) -t string -m -s 0.15 -a $(ANNOTATIONS) -i $< -o $@

$(STRING_NOTM_NET): $(SNET_DIR)/9606.protein.links.detailed.v10.txt
	$(DNET_CMD) -t string -s 0.15 -a $(ANNOTATIONS) -i $< -o $@

$(PF_NET): $(SNET_DIR)/main_FAN.csv
	$(DNET_CMD) -t pf -a $(ANNOTATIONS) -i $< -o $@

derived_networks: $(DNET_DIR)/string_notm.tsv $(DNET_DIR)/string.tsv $(DNET_DIR)/pf.tsv

# Kernels
KERNEL_DIR := kernels
DNETS := $(shell ls $(DNET_DIR)/*.tsv)
KERNEL_CMD := java -Xmx24g -jar $(UBERJAR) kernel
ALPHA := 0.001

$(KERNEL_DIR)/%_reglap.mat: $(DNET_DIR)/%.tsv
	$(KERNEL_CMD) -a $(ALPHA) -i $< -o $@

kernels: $(DNETS:$(DNET_DIR)/%.tsv=$(KERNEL_DIR)/%_reglap.mat)

# Results
## PROMISING
RESULTS_DIR := results
P_RESULTS_DIR := $(RESULTS_DIR)/promising
PVAL_ITERATIONS := 5000
PROMISING_CMD := dependencies/PROMISING/src/promising -p $(PVAL_ITERATIONS)

$(P_RESULTS_DIR)/string/%.tsv: $(GENESETS_DIR)/%.gmt
	$(PROMISING_CMD) -m $(KERNEL_DIR)/string_reglap.mat -g $< -o $@

$(P_RESULTS_DIR)/string_notm/%.tsv: $(GENESETS_DIR)/%.gmt
	$(PROMISING_CMD) -m $(KERNEL_DIR)/string_notm_reglap.mat -g $< -o $@

$(P_RESULTS_DIR)/pf/%.tsv: $(GENESETS_DIR)/%.gmt
	$(PROMISING_CMD) -m $(KERNEL_DIR)/pf_reglap.mat -g $< -o $@

promising_results: $(CASES:%=$(P_RESULTS_DIR)/string/%.tsv) $(CASES:%=$(P_RESULTS_DIR)/string_notm/%.tsv) $(CASES:%=$(P_RESULTS_DIR)/pf/%.tsv)

## PF
PF_RESULTS_DIR := results/pf
PF_CMD := Rscript dependencies/prix_fixe/run_pf.r

$(PF_RESULTS_DIR)/string/%.tsv: $(GENESETS_DIR)/%.gmt
	$(PF_CMD) $< $(STRING_NET) $@

$(PF_RESULTS_DIR)/string_notm/%.tsv: $(GENESETS_DIR)/%.gmt
	$(PF_CMD) $< $(STRING_NOTM_NET) $@

$(PF_RESULTS_DIR)/pf/%.tsv: $(GENESETS_DIR)/%.gmt
	$(PF_CMD) $< $(PF_NET) $@

pf_results: $(CASES:%=$(PF_RESULTS_DIR)/string/%.tsv) $(CASES:%=$(PF_RESULTS_DIR)/string_notm/%.tsv) $(CASES:%=$(PF_RESULTS_DIR)/pf/%.tsv)

results: kernels promising_results pf_results

# MONARCH known genes
SMONARCH_DIR := monarch_source
DMONARCH_DIR := monarch_derived
MONARCH_CMD := java -jar $(UBERJAR) monarch
SMONARCH_FILES := $(shell ls $(SMONARCH_DIR)/*.tsv)
MCASES := $(SMONARCH_FILES:$(SMONARCH_DIR)/%.tsv=%)

$(DMONARCH_DIR)/%.txt: $(SMONARCH_DIR)/%.tsv
	$(MONARCH_CMD) -i $< -o $@

monarch: $(MCASES:%=$(DMONARCH_DIR)/%.txt)

# Validation
VALIDATION_CMD := java -jar $(UBERJAR) validate
VALIDATION_DIR := validation
VALIDATION_FILENAME := validation.tsv
VALIDATION_FILEPATH := $(VALIDATION_DIR)/$(VALIDATION_FILENAME)
PVAL_ITERATIONS_VAL := 1000

$(VALIDATION_FILEPATH): $(RESULTS_DIR)/*/*/*.tsv
	$(VALIDATION_CMD) -r $(RESULTS_DIR) -t $(DMONARCH_DIR) -o $@ -p $(PVAL_ITERATIONS_VAL)

validation: monarch results $(VALIDATION_FILEPATH)

# Validation: GSEA curves
