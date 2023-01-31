library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.util_pkg.all;

entity communication_top is
    generic(fir_ord : natural := 10;
            fixed_point : natural := 1;
            input_data_width : natural := 17;
            output_data_width : natural := 17;
            n : natural := 5;
            k : natural := 3);
    Port (  clk_i : in STD_LOGIC;
			rst_i : in STD_LOGIC;
			--AXI STREAM slave port
			s_axi_tvalid : in STD_LOGIC;
			s_axi_tready : out STD_LOGIC;
			s_axi_tdata : in STD_LOGIC_VECTOR(input_data_width-1 downto 0);	
			s_axi_tlast : in STD_LOGIC;
			--AXI STREAM master port
			m_axi_tvalid : out STD_LOGIC;
			m_axi_tready : in STD_LOGIC;
			m_axi_tdata : out STD_LOGIC_VECTOR(output_data_width-1 downto 0);	
			m_axi_tlast : out STD_LOGIC 
		 );
end communication_top;

architecture Behavioral of communication_top is
    signal we_s : STD_LOGIC;
    signal coef_addr_s : std_logic_vector(log2c(fir_ord+1)-1 downto 0);
    signal coef_s: STD_LOGIC_VECTOR (input_data_width-1 downto 0);
    signal data_i_s : STD_LOGIC_VECTOR (input_data_width-1 downto 0);
    signal data_o_s : STD_LOGIC_VECTOR (output_data_width-1 downto 0); 
    
    signal data_number_reg, data_number_next : std_logic_vector(log2c(fir_ord+1)-1 downto 0);
    signal sent_data_number_reg, sent_data_number_next : std_logic_vector(log2c(fir_ord+1)-1 downto 0);
    signal coef_wr_s : std_logic; --0 coef are not written, 1 coef writting
    type state_type is (idle_s, idle_m, slave_read, master_write, master_last_write);
	signal state_reg_s, state_next_s : state_type;
	signal state_reg_m, state_next_m : state_type;
begin

    fir_filter:
    entity work.fir_top(Behavioral)
    generic map(fir_ord => fir_ord,
                input_data_width => input_data_width,
                output_data_width => output_data_width,
                n => n,
                k => k)
    port map(  clk_i => clk_i,
               rst_i => rst_i,
               we_i => we_s,
               coef_addr_i => coef_addr_s,
               coef_i => coef_s,
               data_i => data_i_s,
               data_o => data_o_s);  
                             
    --State and data registers
	process(clk_i, rst_i)
	begin
		if (rising_edge(clk_i)) then
			if (rst_i = '1') then
				state_reg_s <= idle_s;
				state_reg_m <= idle_m;
				data_number_reg <= (others => '0');
				sent_data_number_reg <= (others => '0');
			else
				state_reg_s <= state_next_s;
				state_reg_m <= state_next_m;
				data_number_reg <= data_number_next;
				sent_data_number_reg <= sent_data_number_next;
			end if;
		end if;
	end process;
	
	AXI_Stream_protocol_implementation_SLAVE:
    process (state_reg_s, s_axi_tvalid, s_axi_tdata, s_axi_tlast, data_number_reg, m_axi_tready) is
    begin
        --Default
        state_next_s <= idle_s;
        s_axi_tready <= '0';
        we_s <= '0';
        coef_addr_s <= (others => '0');
        data_number_next <= (others => '0');                   
        coef_s <= (others => '0');
        
        case state_reg_s is
            when idle_s =>
                if (s_axi_tvalid = '1' and m_axi_tready = '1') then --dont start if other slave is not ready to recieve fir results
                    s_axi_tready <= '1';
                    state_next_s <= slave_read;
                else
                    state_next_s <= idle_s;
                end if;
            when slave_read =>
                s_axi_tready <= '1';
                if (s_axi_tvalid = '1') then
                    we_s <= '1';
                    coef_addr_s <= data_number_reg;
                    data_number_next <= std_logic_vector(unsigned(data_number_reg) + 1);
                    coef_s <= s_axi_tdata;
                    
                    if (s_axi_tlast = '1') then
                        state_next_s <= idle_s;
                    else 
                        state_next_s <= slave_read;
                    end if;
                else
                    state_next_s <= slave_read; --wait for tvalid
                    data_number_next <= data_number_reg;
                end if;
            when others =>
        end case;
    end process;
    
    AXI_Stream_protocol_implementation_MASTER:
    process (state_reg_m, m_axi_tready, sent_data_number_reg, sent_data_number_next, data_o_s, s_axi_tlast) is
    begin
        --Default
        state_next_m <= idle_m;
        m_axi_tvalid <= '0';
	    m_axi_tdata <= (others => '0');	
		m_axi_tlast <= '0';
	   -- sent_data_number_next <= (others => '0');
	   
        case state_reg_m is
            when idle_m =>
                -- wait 2 cycles after writing coeficients ?
                if (state_reg_s = slave_read) and (s_axi_tvalid = '1') and (m_axi_tready = '1') then
                    state_next_m <= master_write;
                else
                    state_next_m <= idle_m;
                end if;
            when master_write =>
                
                m_axi_tvalid <= '1';
                m_axi_tdata <= data_o_s;
              --  sent_data_number_next <= std_logic_vector(unsigned(sent_data_number_reg) + 1);
                
             --   if (sent_data_number_next = std_logic_vector(to_unsigned(fir_ord, log2c(fir_ord+1)))) then
                if s_axi_tlast = '1' then
                    state_next_m <= master_last_write;
                else 
                    state_next_m <= master_write;
                end if;            
            when master_last_write =>
                m_axi_tvalid <= '1';
                m_axi_tdata <= data_o_s;  
                m_axi_tlast <= '1';   
                state_next_m <= idle_m;
            when others =>
        end case;
    end process;
    
end Behavioral;