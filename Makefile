SOURCES = \
		  $(BLUESPECDIR)/Verilog/SizedFIFO.v \
		  $(BLUESPECDIR)/Verilog/SizedFIFO0.v \
		  $(BLUESPECDIR)/Verilog/FIFO1.v \
		  $(BLUESPECDIR)/Verilog/FIFO2.v \
		  $(BLUESPECDIR)/Verilog/FIFO20.v \
		  $(BLUESPECDIR)/Verilog/FIFO10.v \
		  $(BLUESPECDIR)/Verilog/FIFOL1.v \
		  $(BLUESPECDIR)/Verilog/BRAM1.v \
		  $(BLUESPECDIR)/Verilog/BRAM1BELoad.v \
		  $(BLUESPECDIR)/Verilog/BRAM2.v \
		  $(BLUESPECDIR)/Verilog/RevertReg.v \
		  $(BLUESPECDIR)/Verilog/RegFile.v \
		  $(BLUESPECDIR)/Verilog/RegFileLoad.v \
		  top.v rtl/*

include bitstream.mk

PACKAGES = src:BlueLib/src:BlueAXI/src:+

BSC_FLAGS = -show-schedule -show-range-conflict -keep-fires -aggressive-conditions \
						-check-assert -no-warn-action-shadowing -sched-dot

SYNTH_FLAGS = -bdir build -vdir rtl -simdir build \
							-info-dir build -fdir build

BSIM_FLAGS = -bdir bsim -vdir bsim -simdir bsim \
							-info-dir bsim -fdir bsim -D BSIM -l pthread


# Generate verlog files in rtl
compile:
	bsc \
		$(SYNTH_FLAGS) $(BSC_FLAGS) -cpp +RTS -K128M -RTS \
		-p $(PACKAGES) -verilog -u -g mkSoc src/Soc.bsv

# Generate a new simulation file and run simulation
sim:
	bsc $(BSC_FLAGS) $(BSIM_FLAGS) -p $(PACKAGES) -sim -u -g mkSoc src/Soc.bsv
	bsc $(BSC_FLAGS) $(BSIM_FLAGS) -sim -e $(BSIM_MODULE) -o \
		bsim/bsim bsim/*.ba
	./bsim/bsim -m 1000000000

# Run simulation without generating a new simulation file
run:
	./bsim/bsim -m 1000000000


