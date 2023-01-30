library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.util_pkg.all;

entity fir_param is
    generic(fir_ord : natural := 10;
            fixed_point : natural := 1;
            input_data_width : natural := 17;
            output_data_width : natural := 17;
            n : natural := 5;
            k : natural := 3);
    Port ( clk_i : in STD_LOGIC;
           we_i : in STD_LOGIC;
           coef_addr_i : in std_logic_vector(log2c(fir_ord+1)-1 downto 0);
           coef_i : in STD_LOGIC_VECTOR (input_data_width-1 downto 0);
           data_i : in STD_LOGIC_VECTOR (input_data_width-1 downto 0);
           data_o : out STD_LOGIC_VECTOR (output_data_width-1 downto 0));
end fir_param;

architecture Behavioral of fir_param is
    type std_2d is array (fir_ord downto 0) of std_logic_vector(2*input_data_width-1 downto 0);
    signal mac_inter : std_2d:=(others=>(others=>'0'));
    type coef_t is array (fir_ord downto 0) of std_logic_vector(input_data_width-1 downto 0);
    signal b_s : coef_t := (others=>(others=>'0')); 
    signal delay_reg : std_logic_vector(2*input_data_width-1 downto 0);  
    
    --voter signals
    signal voter_input_s : std_logic_vector (n*2*input_data_width-1 downto 0);             
    signal voter_output_s : std_logic_vector (2*input_data_width-1 downto 0);                                     
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
    
    voter_section:
    entity work.voter(behavioral)
    generic map(n => n,
                input_data_width => input_data_width,
                output_data_width => output_data_width)
    port map(
            input_i => voter_input_s,
            output_o => voter_output_s);
            
    first_section:
    entity work.mac(behavioral)
    generic map(input_data_width=>input_data_width)
    port map(clk_i=>clk_i,
             u_i=>data_i,
             b_i=>b_s(fir_ord),
             sec_i=>delay_reg,
             sec_o=>mac_inter(0));
                     
    other_sections:
    for i in 1 to fir_ord generate
        fir_section:
        entity work.mac(behavioral)
        generic map(input_data_width=>input_data_width)
        port map(clk_i=>clk_i,
                 u_i=>data_i,
                 b_i=>b_s(fir_ord-i),
                 sec_i=>mac_inter(i-1),
                 sec_o=>mac_inter(i));
    end generate;
    
    data_o <= mac_inter(fir_ord)(2*input_data_width-1-fixed_point downto 2*input_data_width-output_data_width-fixed_point);
    
end Behavioral;