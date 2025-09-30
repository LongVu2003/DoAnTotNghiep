
a.out: *.v
	iverilog cmult.v qmult.v matrix_multiplier.v c_mac.v tb_matrix_multiplier.sv
tb.vcd : a.out
	./a.out
debug :tb.vcd
	gtkwave tb.vcd
clean : *.out *.vcd
	rm -f *.out *.vcd

	
