.PHONY: clean_files

menhir_files := $(wildcard $(SRC_DIR)/*.mly)
old_src_dir := $(SRC_DIR)

SRC_DIR = src

LIB_MODULES = $(notdir $(menhir_files:%.mly=%.ml))
NON_LIB_MODULES = oiq_match_query_parser_errors.ml

$(SRC_DIR)/oiq_match_query_parser_errors.ml: $(old_src_dir)/oiq_match_query_parser.mly $(old_src_dir)/oiq_match_query_parser_errors.messages
	menhir $(old_src_dir)/oiq_match_query_parser.mly --compile-errors $(old_src_dir)/oiq_match_query_parser_errors.messages > $@

$(SRC_DIR)/%.ml $(SRC_DIR)/%.mli: $(old_src_dir)/%.mly
	mkdir -p $(SRC_DIR)
	cp $^ $(SRC_DIR)/
	menhir --explain --table --ocamlc 'ocamlfind ocamlc -thread -package $(subst $(space),$(comma),$(PACKAGES))' --infer $(SRC_DIR)/$(notdir $^)

clean: clean_files

clean_files:
	rm "$(SRC_DIR)/oiq_match_query_parser.ml" \
	   "$(SRC_DIR)/oiq_match_query_parser.mli"
