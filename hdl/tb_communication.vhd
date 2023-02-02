library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_unsigned.all;
use IEEE.NUMERIC_STD.ALL;
use std.textio.all;
use work.txt_util.all;
use work.util_pkg.all;

entity tb_communication is
    generic(in_out_data_width : natural := 17;
            fixed_point : natural := 1;
            fir_ord : natural := 5;
            n : natural := 3;
            k : natural := 2);
--  Port ( );
end tb_communication;

architecture Behavioral of tb_communication is
    constant period : time := 20 ns;
    signal clk_i_s : std_logic;
    signal rst_i_s : std_logic;
    signal we_i_s : std_logic;
    file input_test_vector : text open read_mode is "..\..\..\..\..\matlab\input.txt";
    file output_check_vector : text open read_mode is "..\..\..\..\..\matlab\expected.txt";
    file input_coef : text open read_mode is "..\..\..\..\..\matlab\coef.txt";
    
    signal s_axi_tvalid_s : STD_LOGIC;
	signal s_axi_tready_s : STD_LOGIC;
	signal s_axi_tdata_s : STD_LOGIC_VECTOR(in_out_data_width-1 downto 0);	
	signal s_axi_tlast_s : STD_LOGIC;
    signal m_axi_tvalid_s : STD_LOGIC;
    signal m_axi_tready_s : STD_LOGIC;
	signal m_axi_tdata_s : STD_LOGIC_VECTOR(in_out_data_width-1 downto 0);	
	signal m_axi_tlast_s : STD_LOGIC;
    
    signal coef_addr_i_s : std_logic_vector(log2c(fir_ord)-1 downto 0);
    signal coef_i_s : std_logic_vector(in_out_data_width-1 downto 0);
    
    signal start_check : std_logic := '0';
    signal end_s : unsigned(1 downto 0);

begin

    uut_fir_filter_comm:
    entity work.communication_top(behavioral)
    generic map(fir_ord=>fir_ord,
                fixed_point=>fixed_point,
                input_data_width=>in_out_data_width,
                output_data_width=>in_out_data_width,
                n => n,
                k => k)
    port map(clk_i=>clk_i_s,
             rst_i=>rst_i_s,
             we_i=>we_i_s,
             s_axi_tvalid=>s_axi_tvalid_s,
			 s_axi_tready=>s_axi_tready_s, 
			 s_axi_tdata=>s_axi_tdata_s,
			 s_axi_tlast=>s_axi_tlast_s,
			 m_axi_tvalid=>m_axi_tvalid_s,
			 m_axi_tready=>m_axi_tready_s,
			 m_axi_tdata=>m_axi_tdata_s,
			 m_axi_tlast=>m_axi_tlast_s,
			 coef_addr_i=>coef_addr_i_s,
             coef_i=>coef_i_s);

    clk_process:
    process
    begin
        clk_i_s <= '0';
        wait for period/2;
        clk_i_s <= '1';
        wait for period/2;
    end process;
    
    stim_process:
    process
        variable tv : line;
    begin
        s_axi_tvalid_s <= '0';
        s_axi_tdata_s <= (others=>'0');
        s_axi_tlast_s <= '0';
        end_s <= "00";
   
        rst_i_s <= '1';
        wait until falling_edge(clk_i_s);
        rst_i_s <= '0';
        
        --upis koeficijenata
        wait until falling_edge(clk_i_s);
        for i in 0 to fir_ord loop
            we_i_s <= '1';
            coef_addr_i_s <= std_logic_vector(to_unsigned(i,log2c(fir_ord)));
            readline(input_coef,tv);
            coef_i_s <= to_std_logic_vector(string(tv));
            wait until falling_edge(clk_i_s);
        end loop;
        
        --ulaz za filtriranje (koriscenjem axi stream protokola)
        readline(input_test_vector,tv); 
        s_axi_tdata_s <= to_std_logic_vector(string(tv));  --prvi odbirak postavljen na liniju za podatke
        s_axi_tvalid_s <= '1';
        wait until falling_edge(clk_i_s);
        while (s_axi_tready_s /= '1') loop   --cekanje na handshake
            wait until falling_edge(clk_i_s);
        end loop;
        
        readline(input_test_vector,tv);
        while (end_s < "10") loop
            s_axi_tdata_s <= to_std_logic_vector(string(tv));
            wait until falling_edge(clk_i_s);
            start_check <= '1'; --drugi slave uredjaj je spreman da prima odbirke na izlazu filtra
            if (end_s = "00") then
                readline(input_test_vector,tv);
            end if;
            if (endfile(input_test_vector)) then
                if (end_s = "00") then
                    s_axi_tlast_s <= '1';
                else 
                    s_axi_tlast_s <= '0';
                    s_axi_tvalid_s <= '0';
                    s_axi_tdata_s <= (others=>'0');
                end if;
                end_s <= end_s + 1; --videti da li ovo pravi petlju ????
            end if;
        end loop;
        start_check <= '0';
        wait;
    end process;
    
    check_process:
    process
        variable check_v : line;
        variable tmp : std_logic_vector(in_out_data_width-1 downto 0);
    begin
        m_axi_tready_s <= '1';
        wait until start_check = '1';
        for i in 0 to fir_ord loop --proveriti !!!!!!!!!!!!! da li treba +1 (izbaceno jer je readline jedan izbacen ranije)
            wait until rising_edge(clk_i_s); --wait because of input registers
        end loop;
        while(true)loop
            wait until rising_edge(clk_i_s);
            readline(output_check_vector,check_v);
            tmp := to_std_logic_vector(string(check_v));
            if(abs(signed(tmp) - signed(m_axi_tdata_s)) > "000000000000000000000111")then
                report "result mismatch!" severity failure;
            end if;
            if m_axi_tlast_s = '1' then
                report "verification done!" severity failure; 
            end if;
        end loop;
    end process;
    
end Behavioral;