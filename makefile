
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

all: all_validation

clean: clean_snps clean_gsets

# Dependencies
$(UBERJAR) $(PROMSING_BIN) $(ANNOTATIONS):
	bash install.sh

# SNPs
DSNPS_DIR := snps_derived
TRAITS_CMD := $(BASE_CMD) select-traits
PVAL_THRESH := 1 # 5e-8 # take everything
SNPS_CMD := $(BASE_CMD) snps -p $(PVAL_THRESH)

$(SSNPS_DIR)/%_traits.txt: $(SSNPS_DIR)/%.tsv $(UBERJAR)
	$(TRAITS_CMD) -i $< -o $@

$(DSNPS_DIR)/%.txt: $(SSNPS_DIR)/%_traits.txt $(SSNPS_DIR)/%.tsv $(UBERJAR)
	$(SNPS_CMD) -t $< -i $(@:$(DSNPS_DIR)/%.txt=$(SSNPS_DIR)/%.tsv) -o $@

snps: $(SNP_CASES:%=$(SSNPS_DIR)/%_traits.txt) $(SNP_CASES:%=$(DSNPS_DIR)/%.txt)

clean_snps:
	rm $(SNP_CASES:%=$(SSNPS_DIR)/%_traits.txt) $(SNP_CASES:%=$(DSNPS_DIR)/%.txt)

# Genesets
GENESETS_DIR := genesets
GENESETS_CMD := $(BASE_CMD) genesets
FLANK := 100000

$(GENESETS_DIR)/%.gmt: $(DSNPS_DIR)/%.txt $(UBERJAR)
	$(GENESETS_CMD) -i $< -o $@ -f $(FLANK)

gsets: $(SNP_CASES:%=$(GENESETS_DIR)/%.gmt)

clean_gsets:
	rm $(SNP_CASES:%=$(GENESETS_DIR)/%.gmt)

# Derived networks
SNET_DIR := networks_source
DNET_DIR := networks_derived
DNET_CMD := $(BASE_CMD) network
STRING_NET := $(DNET_DIR)/string.tsv
STRINGNOTM_NET := $(DNET_DIR)/stringnotm.tsv
PF_NET := $(DNET_DIR)/pf-cfn.tsv
NETWORK_PATHS := $(STRING_NET) $(STRINGNOTM_NET) $(PF_NET)
NETWORK_CASES := $(NETWORK_PATHS:$(DNET_DIR)/%.tsv=%)

$(STRING_NET): $(SNET_DIR)/9606.protein.links.detailed.v10.txt $(UBERJAR) $(ANNOTATIONS)
	$(DNET_CMD) -t string -m -s 0.15 -a $(ANNOTATIONS) -i $< -o $@

$(STRINGNOTM_NET): $(SNET_DIR)/9606.protein.links.detailed.v10.txt $(UBERJAR) $(ANNOTATIONS)
	$(DNET_CMD) -t string -s 0.15 -a $(ANNOTATIONS) -i $< -o $@

$(PF_NET): $(SNET_DIR)/main_FAN.csv $(UBERJAR) $(ANNOTATIONS)
	$(DNET_CMD) -t pf -a $(ANNOTATIONS) -i $< -o $@

networks: $(NETWORK_PATHS)
#networks: $(DNET_DIR)/stringnotm.tsv $(DNET_DIR)/string.tsv $(DNET_DIR)/pf.tsv

clean_networks:
	rm $(DNET_DIR)/*.tsv

# Kernels
KERNEL_DIR := kernels
KERNEL_CMD := java -Xmx24g -jar $(UBERJAR) kernel
PF_KERNEL_OPTS := -t vonneumann -a 0.000001
STRING_KERNEL_OPTS := -t reglaplacian -a 0.0075
STRINGNOTM_KERNEL_OPTS := -t reglaplacian -a 0.0075
STRING_KERNEL := $(KERNEL_DIR)/string_kernel.mat
STRINGNOTM_KERNEL := $(KERNEL_DIR)/stringnotm_kernel.mat
PF_KERNEL := $(KERNEL_DIR)/pf-cfn_kernel.mat

$(STRING_KERNEL): $(STRING_NET) $(UBERJAR)
	$(KERNEL_CMD) $(STRING_KERNEL_OPTS) -i $< -o $@

$(STRINGNOTM_KERNEL): $(STRINGNOTM_NET) $(UBERJAR)
	$(KERNEL_CMD) $(STRINGNOTM_KERNEL_OPTS) -i $< -o $@

$(PF_KERNEL): $(PF_NET) $(UBERJAR)
	$(KERNEL_CMD) $(PF_KERNEL_OPTS) -i $< -o $@

all_kernels: $(NETWORK_CASES:%=$(KERNEL_DIR)/%_kernel.mat)

# Degree groups
GENES_PER_DEGREE_GROUP := 500
DEGREE_CMD := $(BASE_CMD) degree-groups -s $(GENES_PER_DEGREE_GROUP)

$(DNET_DIR)/%_degree-groups.gmt: $(DNET_DIR)/%.tsv $(UBERJAR)
	$(DEGREE_CMD) -n $< -o $@

# Results
GENESET_CASES := $(patsubst $(GENESETS_DIR)/%.gmt,%,$(wildcard $(GENESETS_DIR)/*.gmt))
ALL_CASES := $(SNP_CASES) $(GENESET_CASES)
ALL_CASES := $(sort $(ALL_CASES))

## PROMISING
RESULTS_DIR := results
PROMISING := promising
#P_RESULTS_DIR := $(RESULTS_DIR)/$(PROMISING)
PVAL_ITERATIONS := 1000
PROMISING_CMD := $(PROMISING_BIN)
#-z complete -s 4
# -p $(PVAL_ITERATIONS)

$(foreach c,$(ALL_CASES),$(RESULTS_DIR)/$(c)):
	if [ ! -d $@ ]; then mkdir -p $@; fi;

$(RESULTS_DIR)/%/$(PROMISING): $(RESULTS_DIR)/%
	if [ ! -d $@ ]; then mkdir -p $@; fi;

PROMISING_FAST := promisingfast
$(RESULTS_DIR)/%/$(PROMISING_FAST): $(RESULTS_DIR)/%
	if [ ! -d $@ ]; then mkdir -p $@; fi;

PROMISING_SIMPLE := promisingsimple
$(RESULTS_DIR)/%/$(PROMISING_SIMPLE): $(RESULTS_DIR)/%
	if [ ! -d $@ ]; then mkdir -p $@; fi;

PROMISING_SUM := promisingsum
$(RESULTS_DIR)/%/$(PROMISING_SUM): $(RESULTS_DIR)/%
	if [ ! -d $@ ]; then mkdir -p $@; fi;

PROMISING_COMPLETE3 := promisingcomplete3
$(RESULTS_DIR)/%/$(PROMISING_COMPLETE3): $(RESULTS_DIR)/%
	if [ ! -d $@ ]; then mkdir -p $@; fi;

PROMISING_COMPLETE5 := promisingcomplete5
$(RESULTS_DIR)/%/$(PROMISING_COMPLETE5): $(RESULTS_DIR)/%
	if [ ! -d $@ ]; then mkdir -p $@; fi;


PROMISING_TEST := promisingtest2
$(RESULTS_DIR)/%/$(PROMISING_TEST): $(RESULTS_DIR)/%
	if [ ! -d $@ ]; then mkdir -p $@; fi;

# trait_method_network.tsv
# ad_promising_string.tsv
## This secondary expansion stuff is gnarly...
.SECONDEXPANSION:
$(foreach c,$(ALL_CASES),$(RESULTS_DIR)/$(c)/$(PROMISING)/%.tsv): $(KERNEL_DIR)/$$(subst .tsv,,$$(word 3,$$(subst _, ,$$(@F))))_kernel.mat $(GENESETS_DIR)/$$(subst .tsv,,$$(word 1,$$(subst _, ,$$(@F)))).gmt $(RESULTS_DIR)/$$(subst .tsv,,$$(word 1,$$(subst _, ,$$(@F))))/$(PROMISING) $(DNET_DIR)/$$(subst .tsv,,$$(word 3,$$(subst _, ,$$(@F))))_degree-groups.gmt
	$(PROMISING_CMD) -z complete -s 4 -m $< -g $(word 2,$^) -o $@ #-d $(word 4,$^)

# promisingfast/[case]_promisingfast_[network].tsv
$(foreach c,$(ALL_CASES),$(RESULTS_DIR)/$(c)/$(PROMISING_FAST)/%.tsv): $(KERNEL_DIR)/$$(subst .tsv,,$$(word 3,$$(subst _, ,$$(@F))))_kernel.mat $(GENESETS_DIR)/$$(subst .tsv,,$$(word 1,$$(subst _, ,$$(@F)))).gmt $(RESULTS_DIR)/$$(subst .tsv,,$$(word 1,$$(subst _, ,$$(@F))))/$(PROMISING_FAST) $(DNET_DIR)/$$(subst .tsv,,$$(word 3,$$(subst _, ,$$(@F))))_degree-groups.gmt
	$(PROMISING_CMD) -z fast -m $< -g $(word 2,$^) -o $@ #-d $(word 4,$^)


$(foreach c,$(ALL_CASES),$(RESULTS_DIR)/$(c)/$(PROMISING_SIMPLE)/%.tsv): $(KERNEL_DIR)/$$(subst .tsv,,$$(word 3,$$(subst _, ,$$(@F))))_kernel.mat $(GENESETS_DIR)/$$(subst .tsv,,$$(word 1,$$(subst _, ,$$(@F)))).gmt $(RESULTS_DIR)/$$(subst .tsv,,$$(word 1,$$(subst _, ,$$(@F))))/$(PROMISING_SIMPLE) $(DNET_DIR)/$$(subst .tsv,,$$(word 3,$$(subst _, ,$$(@F))))_degree-groups.gmt
	$(PROMISING_CMD) -z simple -m $< -g $(word 2,$^) -o $@ #-d $(word 4,$^)

$(foreach c,$(ALL_CASES),$(RESULTS_DIR)/$(c)/$(PROMISING_SUM)/%.tsv): $(KERNEL_DIR)/$$(subst .tsv,,$$(word 3,$$(subst _, ,$$(@F))))_kernel.mat $(GENESETS_DIR)/$$(subst .tsv,,$$(word 1,$$(subst _, ,$$(@F)))).gmt $(RESULTS_DIR)/$$(subst .tsv,,$$(word 1,$$(subst _, ,$$(@F))))/$(PROMISING_SUM) $(DNET_DIR)/$$(subst .tsv,,$$(word 3,$$(subst _, ,$$(@F))))_degree-groups.gmt
	$(PROMISING_CMD) -z sum -m $< -g $(word 2,$^) -o $@ #-d $(word 4,$^)

$(foreach c,$(ALL_CASES),$(RESULTS_DIR)/$(c)/$(PROMISING_COMPLETE3)/%.tsv): $(KERNEL_DIR)/$$(subst .tsv,,$$(word 3,$$(subst _, ,$$(@F))))_kernel.mat $(GENESETS_DIR)/$$(subst .tsv,,$$(word 1,$$(subst _, ,$$(@F)))).gmt $(RESULTS_DIR)/$$(subst .tsv,,$$(word 1,$$(subst _, ,$$(@F))))/$(PROMISING_COMPLETE3) $(DNET_DIR)/$$(subst .tsv,,$$(word 3,$$(subst _, ,$$(@F))))_degree-groups.gmt
	$(PROMISING_CMD) -z complete -s 3 -m $< -g $(word 2,$^) -o $@ #-d $(word 4,$^)

$(foreach c,$(ALL_CASES),$(RESULTS_DIR)/$(c)/$(PROMISING_COMPLETE5)/%.tsv): $(KERNEL_DIR)/$$(subst .tsv,,$$(word 3,$$(subst _, ,$$(@F))))_kernel.mat $(GENESETS_DIR)/$$(subst .tsv,,$$(word 1,$$(subst _, ,$$(@F)))).gmt $(RESULTS_DIR)/$$(subst .tsv,,$$(word 1,$$(subst _, ,$$(@F))))/$(PROMISING_COMPLETE5) $(DNET_DIR)/$$(subst .tsv,,$$(word 3,$$(subst _, ,$$(@F))))_degree-groups.gmt
	$(PROMISING_CMD) -z complete -s 5 -m $< -g $(word 2,$^) -o $@ #-d $(word 4,$^)

$(foreach c,$(ALL_CASES),$(RESULTS_DIR)/$(c)/$(PROMISING_TEST)/%.tsv): $(KERNEL_DIR)/$$(subst .tsv,,$$(word 3,$$(subst _, ,$$(@F))))_kernel.mat $(GENESETS_DIR)/$$(subst .tsv,,$$(word 1,$$(subst _, ,$$(@F)))).gmt $(RESULTS_DIR)/$$(subst .tsv,,$$(word 1,$$(subst _, ,$$(@F))))/$(PROMISING_TEST) $(DNET_DIR)/$$(subst .tsv,,$$(word 3,$$(subst _, ,$$(@F))))_degree-groups.gmt
	$(PROMISING_CMD) -z test -m $< -g $(word 2,$^) -o $@ #-d $(word 4,$^)

PROMISING_NETWORK_CASES := $(NETWORK_CASES) pf-cfn-amat stringnotm-amat string-amat

promising_results: $$(foreach n, $$(PROMISING_NETWORK_CASES), $$(foreach c, $$(ALL_CASES), $(RESULTS_DIR)/$$(c)/$(PROMISING)/$$(c)_$(PROMISING)_$$(n).tsv $(RESULTS_DIR)/$$(c)/$(PROMISING_FAST)/$$(c)_$(PROMISING_FAST)_$$(n).tsv $(RESULTS_DIR)/$$(c)/$(PROMISING_SIMPLE)/$$(c)_$(PROMISING_SIMPLE)_$$(n).tsv $(RESULTS_DIR)/$$(c)/$(PROMISING_SUM)/$$(c)_$(PROMISING_SUM)_$$(n).tsv $(RESULTS_DIR)/$$(c)/$(PROMISING_COMPLETE3)/$$(c)_$(PROMISING_COMPLETE3)_$$(n).tsv $(RESULTS_DIR)/$$(c)/$(PROMISING_TEST)/$$(c)_$(PROMISING_TEST)_$$(n).tsv $(RESULTS_DIR)/$$(c)/$(PROMISING_COMPLETE5)/$$(c)_$(PROMISING_COMPLETE5)_$$(n).tsv))


## PF
PF := pf
PF_CMD := Rscript $(DEP_DIR)/prix_fixe/run_pf.r
#NETWORK_PATHS := $(wildcard $(DNET_DIR)/*.tsv)
#NETWORKS := $(NETWORK_PATHS:$(DNET_DIR)/%.tsv=%)

$(RESULTS_DIR)/%/$(PF): $(RESULTS_DIR)/%
	mkdir -p $@

$(foreach c,$(ALL_CASES),$(RESULTS_DIR)/$(c)/$(PF)/%.tsv): $(DNET_DIR)/$$(subst .tsv,,$$(word 3,$$(subst _, ,$$(@F)))).tsv $(GENESETS_DIR)/$$(subst .tsv,,$$(word 1,$$(subst _, ,$$(@F)))).gmt $(RESULTS_DIR)/$$(subst .tsv,,$$(word 1,$$(subst _, ,$$(@F))))/$(PF)
	$(PF_CMD) $(word 2,$^) $< $@

# $(PF_RESULTS_DIR):
# 	mkdir -p $(PF_RESULTS_DIR)

# $(PF_RESULTS_DIR)/%.tsv: $(PF_RESULTS_DIR) $(GENESETS_DIR)/$$(word 1,$$(subst _, ,$$(@F))).gmt $(DNET_DIR)/$$(shell echo $$(@F) | sed "s/^[^_]*_//g")
# 	mkdir -p $(@D)
# 	$(PF_CMD) $(word 2,$^) $(word 3,$^) $@

pf_results: $$(foreach n, $$(NETWORK_CASES), $$(foreach c, $$(ALL_CASES), $(RESULTS_DIR)/$$(c)/$(PF)/$$(c)_pf_$$(n).tsv))

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
PVAL_ITERATIONS_VAL := 10
VALIDATION_CMD := java -jar $(UBERJAR) validate -p $(PVAL_ITERATIONS_VAL)
VALIDATION_DIR := validation


##$(VALIDATION_FILEPATH): $(wildcard $(RESULTS_DIR)/*.tsv)
##	$(VALIDATION_CMD) -r $(RESULTS_DIR) -t $(DMONARCH_DIR) -o $@ -p $(PVAL_ITERATIONS_VAL)

##validation: monarch results $(VALIDATION_FILEPATH)

RESULTS = $(shell find $(RESULTS_DIR) -iname "*.tsv")
COMMON_CMD := $(BASE_CMD) commonalities
COMMON_GENE_SUFFIX := common.glist
METHODS := pf promising

$(foreach c,$(ALL_CASES),$(foreach n,$(NETWORK_CASES),$(VALIDATION_DIR)/$(c)/$(c)_$(n)_$(COMMON_GENE_SUFFIX))): $(foreach m, $(METHODS),$(RESULTS_DIR)/$$(word 1,$$(subst _, ,$$(@F)))/$(m)/$$(word 1,$$(subst _, ,$$(@F)))_$(m)_$$(word 2,$$(subst _, ,$$(@F))).tsv)
	echo $(foreach m, $(METHODS),$(RESULS_DIR)/$(word 1,$(subst _, ,$(@F)))/$(word 1,$(subst _, ,$(@F)))_$(m)_$(word 2,$(subst _, ,$(@F))).tsv)
	mkdir -p $(@D)
	$(COMMON_CMD) -o $@ $(RESULTS_DIR)/$(word 1,$(subst _, ,$(@F)))/*/$(word 1,$(subst _, ,$(@F)))_*_$(word 2,$(subst _, ,$(@F))).tsv

$(VALIDATION_DIR)/%.txt: $(RESULTS_DIR)/%.tsv $(DMONARCH_DIR)/$$(word 1,$$(subst _, ,$$(@F))).txt $(VALIDATION_DIR)/$$(word 1,$$(subst _, ,$$(@F)))/$$(word 1,$$(subst _, ,$$(@F)))_$$(word 3,$$(subst .txt,,$$(subst _, ,$$(@F))))_$(COMMON_GENE_SUFFIX) $(UBERJAR)
	mkdir -p $(@D)
	$(VALIDATION_CMD) -r $< -t $(word 2,$^) -o $@ -c $(word 3,$^)

all_validation: $(RESULTS:$(RESULTS_DIR)/%.tsv=$(VALIDATION_DIR)/%.txt)

commonalities: $(foreach c,$(ALL_CASES), $(foreach n,$(NETWORK_CASES),$(VALIDATION_DIR)/$(c)/$(c)_$(n)_$(COMMON_GENE_SUFFIX)))

# Evaluation
ENRICHMENT_DIR := $(VALIDATION_DIR)/enrichment_figures
ENRICHMENT_CMD := $(BASE_CMD) enrichment-figure

$(ENRICHMENT_DIR)/%.pdf: #all_results monarch $(UBERJAR)
	mkdir -p $(ENRICHMENT_DIR)
	$(ENRICHMENT_CMD) -t $(DMONARCH_DIR)/$(@F:%.pdf=%).txt -o $@ $(wildcard $(RESULTS_DIR)/*/$(@F:%.pdf=%)_*)

COMPARISON_CMD := $(BASE_CMD) comparison
comparison: #all_results
	$(COMPARISON_CMD) -r $(RESULTS_DIR) -t $(DMONARCH_DIR) -v $(VALIDATION_DIR) -o $(VALIDATION_DIR)/comparison.tsv

OMIM_DIR := omim
PHENOTYPIC_SERIES_FILE := $(OMIM_DIR)/phenotypic-series-all.txt
NUM_GENES_LOCUS := 50
OMIM_CMD := $(BASE_CMD) omim-genesets-cmd -i $(PHENOTYPIC_SERIES_FILE) -a $(ANNOTATIONS) -g $(GENESETS_DIR) -t $(DMONARCH_DIR) -n $(NUM_GENES_LOCUS)

all_omim: $(PHENOTYPIC_SERIES_FILE)
	$(OMIM_CMD)

touch:
	touch snps_source/*_traits.txt
	touch snps_derived/*.txt
	touch genesets/*.gmt
	touch networks_derived/*.tsv
	touch networks_derived/*.gmt
	touch kernels/*.mat
	touch results/*/*/*.tsv
	touch monarch_derived/*.txt
	touch validation/*/*$(COMMON_GENE_SUFFIX)
	touch validation/*/*/*.txt
