
a.out: *.v
	iverilog soml_decoder_top.v matrix_multiplier.v c_mac.v cmult.v qmult.v  Dh_cal.v fxp_div_pipe.v fxp_zoom.v  g_matrix_caculator.v trace_caculator.v delay_module.v  MinFinder.v MinSelector.v comparator.v DistanceSquare.v Rq_cal.v dq_cal.v find_min.v output_signal.v determine_tx_signal.v tb_top.sv mydff.v
tb.vcd : a.out
	./a.out
debug :clean tb.vcd
	gtkwave tb.vcd
clean : 
	rm -f *.out *.vcd

	
