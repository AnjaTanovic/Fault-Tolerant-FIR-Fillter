set time_i 1000
set fir_ord 5
set n 3
set k 2
set time_end 5000
 
# Prikazano korektno ponasanje ukoliko se unose greske a idalje postoje moduli koji mogu da zamene pogresne
for {set x 0} {$x < ($fir_ord - 1)} {incr x 1} {
    for {set y 0} {$y < ($n/2 + $k)} {incr y 1} {

        # Postavljanje hijerarhijske putanje do signala nad kojim vrsi forsiranje
        if {$x == 0} {
            set force_path {/tb_communication/uut_fir_filter_comm/fir_filter/\redundancy_sections(0)\/redundancy_modul/inputs_s}
        } elseif {$x == 1} {
            set force_path {/tb_communication/uut_fir_filter_comm/fir_filter/\redundancy_sections(1)\/redundancy_modul/inputs_s}
        } elseif {$x == 2} {
            set force_path {/tb_communication/uut_fir_filter_comm/fir_filter/\redundancy_sections(2)\/redundancy_modul/inputs_s}
        } else {
            set force_path {/tb_communication/uut_fir_filter_comm/fir_filter/\redundancy_sections(3)\/redundancy_modul/inputs_s}
        }
        append force_path [$y]
        
        # Postavljanje vremenskog trenutka u kome je potrebno izvrsiti forsiranje vrednosti
        set time_c $time_i
        set time_string [append time_c ns]
        
        # Postavljanje vremenskog trenutka u kome treba prekinuti forsiranje vrednosti
        set cancel_f_time $time_end
        set cancel_string [append cancel_f_time ns]
        
        add_force $force_path -radix hex 0 $time_string -cancel_after $cancel_string

        incr time_i 1000
    }
    #set time_i 0
    incr time_end 5000
}

# Prikazano ponasanje prilikom ubacenih greski u mac module (prvi red modula), dovoljan broj rezervi 
for {set y 0} {$y < ($n/2 + $k)} {incr y 1} {

    # Postavljanje hijerarhijske putanje do signala nad kojim vrsi forsiranje
    if {$y == 0} {
        set force_path {/tb_communication/uut_fir_filter_comm/fir_filter/\first_section(3)\/first_mac/reg_sum_s}
    } elseif {$y == 1} {
        set force_path {/tb_communication/uut_fir_filter_comm/fir_filter/\first_section(2)\/first_mac/reg_sum_s}
    } elseif {$y == 2} {
        set force_path {/tb_communication/uut_fir_filter_comm/fir_filter/\first_section(1)\/first_mac/reg_sum_s}
    } else {
        set force_path {/tb_communication/uut_fir_filter_comm/fir_filter/\first_section(4)\/first_mac/reg_sum_s}
    }
    
    # Postavljanje vremenskog trenutka u kome je potrebno izvrsiti forsiranje vrednosti
    set time_c $time_i
    set time_string [append time_c ns]
    
    # Postavljanje vremenskog trenutka u kome treba prekinuti forsiranje vrednosti
    set cancel_f_time $time_end
    set cancel_string [append cancel_f_time ns]
    
    add_force $force_path -radix hex 3ffffffff $time_string -cancel_after $cancel_string

    incr time_i 1000
}
incr time_i 4000
incr time_end 10000

# Prikazano korektno ponasanje ukoliko se unose greske toliko da vise ne postoje moduli koji mogu da zamene pogresne
# Nakon poslednjeg otkaza -> failure u simulaciji zbog ne poklapanja rezultata filtra sa ocekivanim rezultatima 
for {set y 0} {$y <= ($n/2 + $k)} {incr y 1} {

    # Postavljanje hijerarhijske putanje do signala nad kojim vrsi forsiranje    
    set force_path {/tb_communication/uut_fir_filter_comm/fir_filter/\redundancy_sections(4)\/redundancy_modul/inputs_s}
    append force_path [$y]
    
    # Postavljanje vremenskog trenutka u kome je potrebno izvrsiti forsiranje vrednosti
    set time_c $time_i
    set time_string [append time_c ns]
    
    # Postavljanje vremenskog trenutka u kome treba prekinuti forsiranje vrednosti
    set cancel_f_time $time_end
    set cancel_string [append cancel_f_time ns]
    
    add_force $force_path -radix hex 0 $time_string -cancel_after $cancel_string

    incr time_i 1000
}