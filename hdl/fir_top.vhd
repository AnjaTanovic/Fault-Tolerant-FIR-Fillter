library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.util_pkg.all;

entity fir_top is
    generic(fir_ord : natural := 10;
            fixed_point : natural := 1;
            input_data_width : natural := 17;
            output_data_width : natural := 17;
            n : natural := 5;
            k : natural := 3);
    Port ( clk_i : in STD_LOGIC;
           rst_i : in STD_LOGIC;
           we_i : in STD_LOGIC;
           coef_addr_i : in std_logic_vector(log2c(fir_ord+1)-1 downto 0);
           coef_i : in STD_LOGIC_VECTOR (input_data_width-1 downto 0);
           data_i : in STD_LOGIC_VECTOR (input_data_width-1 downto 0);
           data_o : out STD_LOGIC_VECTOR (output_data_width-1 downto 0));
end fir_top;

architecture Behavioral of fir_top is
    type std_2d is array (fir_ord downto 0) of std_logic_vector(2*input_data_width-1 downto 0);
--  signal mac_inter : std_2d:=(others=>(others=>'0'));
    type mac_array_inter is array (0 to (n + k) - 1) of std_2d;
    signal mac_inter : mac_array_inter :=(others => (others=>(others=>'0')));
    type coef_t is array (fir_ord downto 0) of std_logic_vector(input_data_width-1 downto 0);
    signal b_s : coef_t := (others=>(others=>'0')); 
    signal delay_reg : std_logic_vector(2*input_data_width-1 downto 0);  
    
    --voter signals
    signal voter_input_s : std_logic_vector (n*2*input_data_width-1 downto 0);             
    signal voter_output_s : std_logic_vector (2*input_data_width-1 downto 0);      
    
    --rendundancy spares signals
    type redundancy_o_array is array (fir_ord downto 0) of std_logic_vector (2*input_data_width-1 downto 0);  
    signal redundancy_output : redundancy_o_array;  
    type redundancy_i_array is array (fir_ord downto 0) of std_logic_vector ((n + k)*2*input_data_width-1 downto 0);
    signal redundancy_input : redundancy_i_array;       
    
    -------------------------------------------------------------
    attribute dont_touch : string;                  
    attribute dont_touch of redundancy_input : signal is "true";                  
    attribute dont_touch of mac_inter : signal is "true";                  
begin

    process(clk_i)
    begin
        if(clk_i'event and clk_i = '1')then
            if we_i = '1' then
                b_s(to_integer(unsigned(coef_addr_i))) <= coef_i;
            end if;
            delay_reg <= (others => '0');
        end if;
    end process;
    
    first_section:
    for r in 0 to (n + k) - 1 generate
        first_mac:
        entity work.mac(behavioral)
        generic map(input_data_width=>input_data_width)
        port map(clk_i=>clk_i,
                 u_i=>data_i,
                 b_i=>b_s(fir_ord),
                 sec_i=>delay_reg,
                 sec_o=>mac_inter(r)(0));
    end generate;
                  
    input_concatanate:  
    process(mac_inter, redundancy_input)
    begin
        for f in 0 to fir_ord loop
           -- redundancy_input(f)(2*input_data_width-1 downto 0) <= mac_inter(0)(f);
            for i in 0 to (n + k) - 1 loop
             --   redundancy_input(f)((i+1)*2*input_data_width-1 downto 0) <= mac_inter(i)(f) & redundancy_input(f)(i*2*input_data_width-1 downto 0);
              redundancy_input(f)(2*input_data_width + 2*input_data_width *i-1 downto 2*input_data_width*i) <= mac_inter(i)(f);
            end loop; 
        end loop; 
    end process;
    
    redundancy_sections:
    for i in 0 to fir_ord generate
        redundancy_modul:
        entity work.redundancy_spares(Behavioral)
        generic map(fir_ord => fir_ord,
                    input_data_width => input_data_width,
                    output_data_width => output_data_width,
                    n => n,
                    k => k)
        port map(clk_i=>clk_i,
                 rst_i=>rst_i,
                 we_i=>we_i,
                 input_i=>redundancy_input(i),
                 output_o=>redundancy_output(i));
    end generate;
        
    other_sections:
    for i in 1 to fir_ord generate
        fir_section:
        for r in 0 to (n + k) - 1 generate
            other_mac:
            entity work.mac(behavioral)
            generic map(input_data_width=>input_data_width)
            port map(clk_i=>clk_i,
                     u_i=>data_i,
                     b_i=>b_s(fir_ord-i),
                     sec_i=>redundancy_output(i-1),
                     sec_o=>mac_inter(r)(i));
        end generate;
    end generate;
    
    data_o <= redundancy_output(fir_ord)(2*input_data_width-1-fixed_point downto 2*input_data_width-output_data_width-fixed_point);
    
end Behavioral;