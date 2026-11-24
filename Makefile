# ==========================================
# Diretórios
# ==========================================
RTL_DIR    := .
TB_DIR     := .
SIM_OUT := build/sim

# ==============================================================================================================================
# Arquivos
# ==============================================================================================================================
RTL_FILES := \
    $(RTL_DIR)/spi_master.sv \

TB_FILES := $(TB_DIR)/clock_gen.sv $(TB_DIR)/spi_master_tb.sv

$(SIM_OUT):
	mkdir -p "$@"

# ==========================================
# Módulos de topo
# ==========================================
RTL_TOP := spi_master
TB_TOP  := spi_master_tb

# Arquivo de formas de onda gerado pelo testbench
WAVE_FILE := waves.fsdb

TIMESCALE ?= 1ns/1ps

# ==========================================
# Flags das ferramentas comerciais
# ==========================================
VLOGAN_FLAGS = -full64 -sverilog -kdb +lint=all +define+FSDB
VCS_FLAGS = -full64 -timescale=$(TIMESCALE) -debug_access+all -kdb

# ==========================================
# Verificação de sintaxe
# ==========================================
#syntax:
#    vlogan $(VLOGAN_FLAGS) $(RTL_FILES) $(MODEL_FILES) $(TB_FILES)

syntax: | $(SIM_OUT)
	cd "$(SIM_OUT)" && vlogan $(VLOGAN_FLAGS) $(abspath $(RTL_FILES) $(MODEL_FILES) $(TB_FILES))

# ==========================================
# Compilação / Elaboração
# ==========================================
#compile: syntax
#    vcs $(VCS_FLAGS) -top $(TB_TOP)

compile: syntax
	cd "$(SIM_OUT)" && vcs $(VCS_FLAGS) -top $(TB_TOP)

# ==========================================
# Simulação
# ==========================================
#run: compile
#    ./simv

run: compile
	cd "$(SIM_OUT)" && ./simv

# ==========================================
# Abrir waveform
# ==========================================
#wave:
#    verdi -ssf $(WAVE_FILE) &

wave:
	cd "$(SIM_OUT)" && verdi -ssf "$(WAVE_FILE)"
 
# ==========================================
# Limpeza da simulação
# ==========================================
clean_sim:
	rm -rf csrc simv* obj_dir *.daidir novas* AN.DB ucli.key verdi* DVEfiles .vlogan* *.fsdb \
	    *.fst *.vcd *.log *.out *.fls *.gz *.fdb_latexmk *.aux
	rm -rf -- "$(SIM_OUT)"

# ==========================================
# Limpeza total
# ==========================================
clean: clean_sim

.PHONY: syntax compile run wave synth clean clean_sim

