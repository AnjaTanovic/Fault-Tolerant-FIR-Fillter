library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.util_pkg.all;

entity communication_top is
    generic(fir_ord : natural := 5;
            fixed_point : natural := 1;
            input_data_width : natural := 17;
            output_data_width : natural := 17;
            n : natural := 5;
            k : natural := 3);
    Port (  clk_i : in STD_LOGIC;
			rst_i : in STD_LOGIC;
			we_i : in STD_LOGIC;
			--AXI STREAM slave port
			s_axi_tvalid : in STD_LOGIC;
			s_axi_tready : out STD_LOGIC;
			s_axi_tdata : in STD_LOGIC_VECTOR(input_data_width-1 downto 0);	
			s_axi_tlast : in STD_LOGIC;
			--AXI STREAM master port
			m_axi_tvalid : out STD_LOGIC;
			m_axi_tready : in STD_LOGIC;
			m_axi_tdata : out STD_LOGIC_VECTOR(output_data_width-1 downto 0);	
			m_axi_tlast : out STD_LOGIC;
			--Ports for coefficients
			coef_addr_i : in std_logic_vector(log2c(fir_ord+1)-1 downto 0);
            coef_i : in STD_LOGIC_VECTOR (input_data_width-1 downto 0)
		 );
end communication_top;

architecture Behavioral of communication_top is
    signal we_s : STD_LOGIC;
    signal coef_addr_s : std_logic_vector(log2c(fir_ord+1)-1 downto 0);
    signal coef_s: STD_LOGIC_VECTOR (input_data_width-1 downto 0);
    signal data_i_s : STD_LOGIC_VECTOR (input_data_width-1 downto 0);
    signal data_o_s : STD_LOGIC_VECTOR (output_data_width-1 downto 0); 
    
    signal coef_wr_s : std_logic; --0 coef are not written, 1 coef writting
    type state_type is (idle_s, idle_m, slave_read, master_write, master_last_writes);
	signal state_reg_s, state_next_s : state_type;
	signal state_reg_m, state_next_m : state_type;
	
	signal tlast_counter_reg, tlast_counter_next : std_logic_vector(log2c(fir_ord+1)-1 downto 0);
begin

    --forward coef signals to fir filter
    coef_addr_s <= coef_addr_i;
    coef_s <= coef_i;
    we_s <= we_i;
    
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
				tlast_counter_reg <= (others => '0');
			else
				state_reg_s <= state_next_s;
				state_reg_m <= state_next_m;
				tlast_counter_reg <= tlast_counter_next;
			end if;
		end if;
	end process;
	
	AXI_Stream_protocol_implementation_SLAVE:
    process (state_reg_s, s_axi_tvalid, s_axi_tdata, s_axi_tlast, m_axi_tready) is
    begin
        --Default
        state_next_s <= idle_s;
        s_axi_tready <= '0';                   
        data_i_s <= (others => '0');
        
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
                    data_i_s <= s_axi_tdata; --forward data to fir filter
                    
                    if (s_axi_tlast = '1') then
                        state_next_s <= idle_s;
                    else 
                        state_next_s <= slave_read;
                    end if;
                else
                    state_next_s <= slave_read; --wait for tvalid
                end if;
            when others =>
        end case;
    end process;
    
    AXI_Stream_protocol_implementation_MASTER:
    process (state_reg_m, state_reg_s, s_axi_tvalid, m_axi_tready, data_o_s, s_axi_tlast, tlast_counter_reg) is
    begin
        --Default
        state_next_m <= idle_m;
        m_axi_tvalid <= '0';
	    m_axi_tdata <= (others => '0');	
		m_axi_tlast <= '0';
		tlast_counter_next <= (others => '0');
	   
        case state_reg_m is
            when idle_m =>
                if (state_reg_s = slave_read) and (s_axi_tvalid = '1') and (m_axi_tready = '1') then 
                    state_next_m <= master_write;
                else
                    state_next_m <= idle_m;
                end if;
            when master_write =>
                m_axi_tvalid <= '1';
                m_axi_tdata <= data_o_s; --forward data from fir filter 
     
                if s_axi_tlast = '1' then  
                    tlast_counter_next <= std_logic_vector(unsigned(tlast_counter_reg) + 1);
                    state_next_m <= master_last_writes;
                else 
                    tlast_counter_next <= tlast_counter_reg;
                    state_next_m <= master_write;
                end if;              
            when master_last_writes =>
                m_axi_tvalid <= '1';
                m_axi_tdata <= data_o_s; 
                tlast_counter_next <= std_logic_vector(unsigned(tlast_counter_reg) + 1); 
                
                if tlast_counter_reg = std_logic_vector(to_unsigned(fir_ord,log2c(fir_ord+1)) + 3) then --still write due to additional registers 
                    m_axi_tlast <= '1';  
                    state_next_m <= idle_m; 
                else
                     m_axi_tlast <= '0';
                     state_next_m <= master_last_writes;   
                end if;
            when others =>
        end case;
    end process;
    
end Behavioral;