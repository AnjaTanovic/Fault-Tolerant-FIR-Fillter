library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_unsigned.all;
use IEEE.NUMERIC_STD.ALL;

entity mac is
    generic (input_data_width : natural := 17);
    Port ( clk_i : in std_logic;
           rst_i : in std_logic;
           u_i : in STD_LOGIC_VECTOR (input_data_width-1 downto 0);
           b_i : in STD_LOGIC_VECTOR (input_data_width-1 downto 0);
           sec_i : in STD_LOGIC_VECTOR (2*input_data_width-1 downto 0);
           sec_o : out STD_LOGIC_VECTOR (2*input_data_width-1 downto 0));
end mac;

architecture Behavioral of mac is

    -----------------------------------------------------------------------------------
    -- Atributes that need to be defined so Vivado synthesizer maps appropriate
    -- code to DSP cells
    attribute use_dsp : string;
    attribute use_dsp of Behavioral : architecture is "yes";
    -----------------------------------------------------------------------------------
    
    signal reg_sum_s : STD_LOGIC_VECTOR (2*input_data_width-1 downto 0):=(others=>'0');
    signal reg_mult_1_s : STD_LOGIC_VECTOR (input_data_width-1 downto 0):=(others=>'0');
    signal reg_mult_2_s : STD_LOGIC_VECTOR (input_data_width-1 downto 0):=(others=>'0');

begin
    process(clk_i)
    begin
        if (clk_i'event and clk_i = '1')then
            if (rst_i = '1') then
                reg_mult_1_s <= (others => '0');
                reg_mult_2_s <= (others => '0');
                reg_sum_s <= (others => '0');
            else
                reg_mult_1_s <= u_i;
                reg_mult_2_s <= b_i;
                reg_sum_s <=  std_logic_vector(signed(sec_i) + (signed(reg_mult_1_s) * signed(reg_mult_2_s)));
            end if;
        end if;
    end process;
    
    sec_o <= reg_sum_s;
    
end Behavioral;