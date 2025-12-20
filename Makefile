
compile: *.v
	iverilog -g2012 -f dut_tb.f 
elab : compile
	./a.out
debug :clean elab
	gtkwave tb.vcd
clean : 
	rm -f *.out *.vcd

	
