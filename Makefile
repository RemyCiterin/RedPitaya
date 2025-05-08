PROJECT = red_pitaya
FAMILY = zynq7
PART = xc7z010clg400-1# XC7Z010-1CLG400C
SOURCES = top.v

#############################################################################################
DBPART = $(shell echo ${PART} | sed -e 's/-[0-9]//g')

TOP ?= ${PROJECT}
TOP_MODULE ?= ${TOP}

XDC ?= red_pitaya.xdc

.PHONY: all
all: build/${PROJECT}.bit

.PHONY: program
program: #build/${PROJECT}.bit
	sudo openFPGALoader --board nexysVideo --bitstream build/${PROJECT}.bit

yosys:
	yosys -q -p \
		"synth_xilinx -flatten -abc9 -arch xc7 -top ${TOP_MODULE}; write_json build/${PROJECT}.json" \
		${SOURCES}

# The chip database only needs to be generated once
# that is why we don't clean it with make clean
db/${DBPART}.bin:
	${PYPY3} ${NEXTPNR_XILINX_PYTHON_DIR}/bbaexport.py \
		--device ${PART} --bba ${DBPART}.bba
	bbasm -l ${DBPART}.bba db/${DBPART}.bin
	rm -f ${DBPART}.bba

build/${PROJECT}.fasm: build/${PROJECT}.json db/${DBPART}.bin ${XDC}
	nextpnr-xilinx \
		--router router1 --chipdb db/${DBPART}.bin --xdc ${XDC} \
		--json build/${PROJECT}.json --fasm $@

build/${PROJECT}.frames: build/${PROJECT}.fasm
	fasm2frames --part ${PART} --db-root ${PRJXRAY_DB_DIR}/${FAMILY} \
		build/${PROJECT}.fasm > build/${PROJECT}.frames

build/${PROJECT}.bit: build/${PROJECT}.frames
	xc7frames2bit \
		--part_file ${PRJXRAY_DB_DIR}/${FAMILY}/${PART}/part.yaml \
		--part_name ${PART} --frm_file build/${PROJECT}.frames \
		--output_file build/${PROJECT}.bit

.PHONY: clean
clean:
	@rm -f build/*.bit
	@rm -f build/*.frames
	@rm -f build/*.fasm
	@rm -f build/*.json
	@rm -f build/*.bin
	@rm -f build/*.bba

.PHONY: pnrclean
pnrclean:
	rm build/*.fasm build/*.frames build/*.bit
