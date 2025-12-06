transcript on
if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

vlog -vlog01compat -work work +incdir+C:/Users/DELL/OneDrive\ -\ ptit.edu.vn/Desktop/SOML_project/code {C:/Users/DELL/OneDrive - ptit.edu.vn/Desktop/SOML_project/code/trace_caculator.v}
vlog -vlog01compat -work work +incdir+C:/Users/DELL/OneDrive\ -\ ptit.edu.vn/Desktop/SOML_project/code {C:/Users/DELL/OneDrive - ptit.edu.vn/Desktop/SOML_project/code/soml_decoder_top.v}
vlog -vlog01compat -work work +incdir+C:/Users/DELL/OneDrive\ -\ ptit.edu.vn/Desktop/SOML_project/code {C:/Users/DELL/OneDrive - ptit.edu.vn/Desktop/SOML_project/code/Rq_cal.v}
vlog -vlog01compat -work work +incdir+C:/Users/DELL/OneDrive\ -\ ptit.edu.vn/Desktop/SOML_project/code {C:/Users/DELL/OneDrive - ptit.edu.vn/Desktop/SOML_project/code/qmult.v}
vlog -vlog01compat -work work +incdir+C:/Users/DELL/OneDrive\ -\ ptit.edu.vn/Desktop/SOML_project/code {C:/Users/DELL/OneDrive - ptit.edu.vn/Desktop/SOML_project/code/output_signal.v}
vlog -vlog01compat -work work +incdir+C:/Users/DELL/OneDrive\ -\ ptit.edu.vn/Desktop/SOML_project/code {C:/Users/DELL/OneDrive - ptit.edu.vn/Desktop/SOML_project/code/MinSelector.v}
vlog -vlog01compat -work work +incdir+C:/Users/DELL/OneDrive\ -\ ptit.edu.vn/Desktop/SOML_project/code {C:/Users/DELL/OneDrive - ptit.edu.vn/Desktop/SOML_project/code/MinFinder.v}
vlog -vlog01compat -work work +incdir+C:/Users/DELL/OneDrive\ -\ ptit.edu.vn/Desktop/SOML_project/code {C:/Users/DELL/OneDrive - ptit.edu.vn/Desktop/SOML_project/code/matrix_multiplier.v}
vlog -vlog01compat -work work +incdir+C:/Users/DELL/OneDrive\ -\ ptit.edu.vn/Desktop/SOML_project/code {C:/Users/DELL/OneDrive - ptit.edu.vn/Desktop/SOML_project/code/g_matrix_caculator.v}
vlog -vlog01compat -work work +incdir+C:/Users/DELL/OneDrive\ -\ ptit.edu.vn/Desktop/SOML_project/code {C:/Users/DELL/OneDrive - ptit.edu.vn/Desktop/SOML_project/code/fxp_zoom.v}
vlog -vlog01compat -work work +incdir+C:/Users/DELL/OneDrive\ -\ ptit.edu.vn/Desktop/SOML_project/code {C:/Users/DELL/OneDrive - ptit.edu.vn/Desktop/SOML_project/code/fxp_div_pipe.v}
vlog -vlog01compat -work work +incdir+C:/Users/DELL/OneDrive\ -\ ptit.edu.vn/Desktop/SOML_project/code {C:/Users/DELL/OneDrive - ptit.edu.vn/Desktop/SOML_project/code/find_min.v}
vlog -vlog01compat -work work +incdir+C:/Users/DELL/OneDrive\ -\ ptit.edu.vn/Desktop/SOML_project/code {C:/Users/DELL/OneDrive - ptit.edu.vn/Desktop/SOML_project/code/dq_cal.v}
vlog -vlog01compat -work work +incdir+C:/Users/DELL/OneDrive\ -\ ptit.edu.vn/Desktop/SOML_project/code {C:/Users/DELL/OneDrive - ptit.edu.vn/Desktop/SOML_project/code/DistanceSquare.v}
vlog -vlog01compat -work work +incdir+C:/Users/DELL/OneDrive\ -\ ptit.edu.vn/Desktop/SOML_project/code {C:/Users/DELL/OneDrive - ptit.edu.vn/Desktop/SOML_project/code/Dh_cal.v}
vlog -vlog01compat -work work +incdir+C:/Users/DELL/OneDrive\ -\ ptit.edu.vn/Desktop/SOML_project/code {C:/Users/DELL/OneDrive - ptit.edu.vn/Desktop/SOML_project/code/determine_tx_signal.v}
vlog -vlog01compat -work work +incdir+C:/Users/DELL/OneDrive\ -\ ptit.edu.vn/Desktop/SOML_project/code {C:/Users/DELL/OneDrive - ptit.edu.vn/Desktop/SOML_project/code/delay_module.v}
vlog -vlog01compat -work work +incdir+C:/Users/DELL/OneDrive\ -\ ptit.edu.vn/Desktop/SOML_project/code {C:/Users/DELL/OneDrive - ptit.edu.vn/Desktop/SOML_project/code/comparator.v}
vlog -vlog01compat -work work +incdir+C:/Users/DELL/OneDrive\ -\ ptit.edu.vn/Desktop/SOML_project/code {C:/Users/DELL/OneDrive - ptit.edu.vn/Desktop/SOML_project/code/cmult.v}
vlog -vlog01compat -work work +incdir+C:/Users/DELL/OneDrive\ -\ ptit.edu.vn/Desktop/SOML_project/code {C:/Users/DELL/OneDrive - ptit.edu.vn/Desktop/SOML_project/code/c_mac.v}
vlog -vlog01compat -work work +incdir+C:/Users/DELL/OneDrive\ -\ ptit.edu.vn/Desktop/SOML_project/uart {C:/Users/DELL/OneDrive - ptit.edu.vn/Desktop/SOML_project/uart/BaudTickGen.v}
vlog -vlog01compat -work work +incdir+C:/Users/DELL/OneDrive\ -\ ptit.edu.vn/Desktop/SOML_project/uart {C:/Users/DELL/OneDrive - ptit.edu.vn/Desktop/SOML_project/uart/async_transmitter.v}
vlog -vlog01compat -work work +incdir+C:/Users/DELL/OneDrive\ -\ ptit.edu.vn/Desktop/SOML_project/uart {C:/Users/DELL/OneDrive - ptit.edu.vn/Desktop/SOML_project/uart/async_receiver.v}
vlog -vlog01compat -work work +incdir+C:/Users/DELL/OneDrive\ -\ ptit.edu.vn/Desktop/SOML_project/uart {C:/Users/DELL/OneDrive - ptit.edu.vn/Desktop/SOML_project/uart/uart_top.v}

vlog -vlog01compat -work work +incdir+C:/Users/DELL/OneDrive\ -\ ptit.edu.vn/Desktop/SOML_project {C:/Users/DELL/OneDrive - ptit.edu.vn/Desktop/SOML_project/tb_soml_decoder.v}

vsim -t 1ps -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L altera_lnsim_ver -L fiftyfivenm_ver -L rtl_work -L work -voptargs="+acc"  tb_soml_decoder

add wave *
view structure
view signals
run -all
