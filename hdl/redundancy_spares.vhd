library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.util_pkg.all;

entity redundancy_spares is
    generic(fir_ord : natural := 10;
            input_data_width : natural := 17;
            output_data_width : natural := 17;
            n : natural := 5;
            k : natural := 3);
    Port ( clk_i : in STD_LOGIC;
           rst_i : in STD_LOGIC;
           input_i : in STD_LOGIC_VECTOR ((n + k)*2*input_data_width-1 downto 0);
           output_o : out STD_LOGIC_VECTOR (2*input_data_width-1 downto 0));
end redundancy_spares;

architecture Behavioral of redundancy_spares is
    type input_array is array(0 to (n + k)-1) of std_logic_vector(2*input_data_width-1 downto 0); 
    signal inputs_s : input_array;  -- n+k inputs (of n+k modules) 
    
    --voter signals  
    signal voter_input_s : std_logic_vector (n*2*input_data_width-1 downto 0);  
    signal voter_output_s : std_logic_vector (2*input_data_width-1 downto 0);                      
    
    --voter registers (inputs)
    type v_regs is array(0 to n - 1) of std_logic_vector(2*input_data_width-1 downto 0); --array of registers before voter
    signal voter_next, voter_reg : v_regs;  
    --offset registers (save input voter component number for next clk)         
    type offset_regs is array(0 to n - 1) of std_logic_vector(log2c(n+k)-1 downto 0); --array of offset registers
    signal offset_next, offset_reg : offset_regs;  
    
    --comparator and stall signals
    type comparators is array(0 to n - 1) of std_logic;
    signal comp : comparators;
    type stall_array is array(0 to n-1 + 1) of std_logic; 
    signal stall : stall_array;  -- stall(n) = 0 => stall
    signal num_of_failure_next, num_of_failure_reg: std_logic_vector(log2c(n+k)-1 downto 0);
begin
    
    input_divide: for i in 0 to (n + k) - 1 generate
        inputs_s((n + k) -1 -i) <= input_i(((n + k)*2*input_data_width-1)-(i*2*input_data_width) downto (((n+k)-1-i)*2*input_data_width));
    end generate;
    
    voter_and_offset_registers:
    process(clk_i)
    begin
        if(clk_i'event and clk_i = '1')then
            if rst_i = '1' then
                for i in 0 to n -1 loop
                    voter_reg(i) <= (others => '0');
                    offset_reg(i) <= (others => '0');
                end loop;
            else
                for i in 0 to n -1 loop
                    voter_reg(i) <= voter_next(i);
                    offset_reg(i) <= offset_next(i);
                end loop;
           end if;
        end if;
    end process;
    
    voter_concatanate:
    process(voter_reg, voter_input_s)
    begin
        --voter_input_s(2*input_data_width-1 downto 0) <= voter_reg(0);
        for i in 0 to n - 1 loop
            --voter_input_s((i+1)*2*input_data_width-1 downto 0) <= voter_reg(i) & voter_input_s(i*2*input_data_width-1 downto 0);
            voter_input_s(2*input_data_width + 2*input_data_width *i-1 downto 2*input_data_width*i) <= voter_reg(i);
        end loop; 
    end process;
    
    voter_section:
    entity work.voter(behavioral)
    generic map(n => n,
                input_data_width => input_data_width,
                output_data_width => output_data_width)
    port map(
            input_i => voter_input_s,
            output_o => voter_output_s);
    
    comparator_logic:
    for i in 0 to n-1 generate
        comp(i) <= '1' when voter_output_s = voter_reg(i)
                   else '0';
    end generate;
    
    stall_logic:
    for i in 0 to n-1 generate
        stall(i+1) <= comp(i) and stall(i);
    end generate;
    
    num_of_failure_registers:
    process(clk_i)
    begin
        if(clk_i'event and clk_i = '1')then
            if rst_i = '1' then
                num_of_failure_reg <= (others => '0');
            else
                num_of_failure_reg <= num_of_failure_next;
            end if;
        end if;
    end process;
    num_of_failure_next <= std_logic_vector(unsigned(num_of_failure_reg) + 1) when stall(n) = '0' --count failures
                           else num_of_failure_reg;
         
    select_mac:
    process (comp, num_of_failure_next, inputs_s, offset_reg)
    begin
        for i in 0 to n -1 loop
            if (comp(i) = '0') then
                offset_next(i) <= num_of_failure_next;
                voter_next(i) <= inputs_s(to_integer(to_unsigned(i,log2c(n+k)) + unsigned(num_of_failure_next)));
            else 
                offset_next(i) <= offset_reg(i);
                voter_next(i) <= inputs_s(to_integer(to_unsigned(i,log2c(n+k)) + unsigned(offset_reg(i))));
            end if;
        end loop;
    end process;
                
    --Final output
    output_o <= voter_output_s;
          
    end Behavioral;
