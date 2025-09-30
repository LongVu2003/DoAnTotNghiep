
cmult.out: *.v
	iverilog cmult.v qmult.v tb_cmult.sv -o cmult.out
tbcmult.vcd : cmult.out
	./cmult.out
debugcmult :tbcmult.vcd
	gtkwave tb_cmult.vcd
clean : *.out *.vcd
	rm -f *.out *.vcd

	
