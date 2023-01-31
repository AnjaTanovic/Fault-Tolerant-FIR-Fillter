library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.util_pkg.all;

entity voter is
    generic(n : natural := 5; --n modular redundancy
            input_data_width : natural := 17;
            output_data_width : natural := 17);
    Port ( input_i : in STD_LOGIC_VECTOR (n*2*input_data_width-1 downto 0);
           output_o : out STD_LOGIC_VECTOR (2*input_data_width-1 downto 0));
end voter;

architecture behavioral of voter is
    shared variable length_glob : integer;

    type input_array is array(0 to n-1) of std_logic_vector(2*input_data_width-1 downto 0); 
    signal inputs_s : input_array;   
    type sum_array is array(0 to n-1-1) of std_logic_vector(log2c(n)-1+1 downto 0); --+1 because it can be numbers 0 to n (and n)
    type sum_bits_array is array(0 to 2*input_data_width-1) of sum_array;
    signal sum_s : sum_bits_array; 
    
    --std_logic_vector(log2c(n)-1+1 downto 0); --+1 because it can be numbers 0 to n (and n)
    
    type smaller_array is array (0 to n/2) of integer; --niz brojeva za svaku kombinaciju (npr 012) ima ih 3 za n = 5, 4 za n = 7 itd (n/2 + 1 clanova)
--    type comb_array is array(integer range <>) of smaller_array; --niz u kojem se nalaze 012 123 124 itd (sve kombinacije)
    type comb_array is array(0 to 100) of smaller_array; --niz u kojem se nalaze 012 123 124 itd (sve kombinacije)
    type input_array_n  is array (0 to n-1) of integer; --brojevi 0 1 2 3 4 .. n-1
    
    function calculate_length(length:integer; 
                              n:integer; 
                              start:integer; 
                              finish:integer; 
                              index:integer; 
                              r:integer) 
                              return integer is
		variable i:integer;
		variable length_tmp: integer;
	begin
	   length_tmp := length;
	   
        if(index = r)then
            length_tmp := length_tmp + 1;
        else
            for i in start to finish loop
                if (finish - i + 1 >= r - index) then
                    length_tmp := calculate_length(length_tmp, n, i+1, finish, index+1, r);  
                end if;
            end loop;
        end if;
        
        
        return length_tmp;
	end calculate_length;
    
    function calculate_length1( n:integer; 
                                start:integer; 
                                finish:integer; 
                                index:integer; 
                                r:integer) 
                                return integer is
		variable i:integer;
		variable length_tmp: integer;
	begin
	   length_tmp := 0;
	   
        if(index = r)then
            length_tmp := length_tmp + 1;
        else
            for i in start to finish loop
                if (finish - i + 1 >= r - index) then
                    length_tmp := length_tmp + calculate_length1(n, i+1, finish, index+1, r);  
                end if;
            end loop;
        end if;
        
        return length_tmp;
	end calculate_length1;
    
    impure function combinations( data:comb_array; 
                           comb:smaller_array; 
                           length:integer; 
                           n:integer; 
                           start:integer; 
                           finish:integer; 
                           index:integer; 
                           r:integer) 
                           return comb_array is
		variable j,i:integer;
		variable arr : input_array_n;
		variable length_tmp: integer;
		variable data_tmp : comb_array;
		variable comb_tmp: smaller_array;
	begin
	
--	   for i in 0 to n-1 loop
--	       arr(i) := i;
--	   end loop;
	   
	   length_tmp := length;
	   data_tmp := data;
	   comb_tmp := comb;
	   
        if index = r then
            data_tmp(length_glob) := comb_tmp;
            length_glob := length_glob + 1;
        else
            for i in start to finish loop
                if (finish - i + 1 >= r - index) then
                    comb_tmp(index) := i; 
                    data_tmp := combinations(data_tmp, comb_tmp, length_tmp, n, i+1, finish, index+1, r);
--                    length_tmp := calculate_length(length_tmp, n, i+1, finish, index+1, r);
--                    length_glob := length_glob + calculate_length1(n, i+1, finish, index+1, r);
--                    length_tmp := length_tmp+1;
                end if;
            end loop;
        end if;
        
--        if length_tmp <= 5 then
--            data_tmp := combinations(data_tmp, comb_tmp, length_tmp+1, n, i+1, finish, index+1, r);
--            data_tmp(length)(0) := length;
--        end if;
        
        return data_tmp;
	end combinations;  
	
    impure function calculate_combinations( n:integer; 
                                     start:integer; 
                                     finish:integer; 
                                     index:integer; 
                                     r:integer) 
                                     return comb_array is
		variable comb : smaller_array; -- := (others => 0);
		variable data : comb_array;-- := (others => (others => 0));
		variable length : integer := 0;
	begin
	   length_glob := 0;
	   return combinations(data, comb, length, n, start, finish, index, r);
	end calculate_combinations;  	

	
	--signal comb : comb_array := calculate_combinations(n, 0, n-1, 0, n/2 + 1);  
	signal comb : comb_array := calculate_combinations(n, 0, n-1, 0, n/2 + 1);
	constant comb_length : integer := calculate_length1(n, 0, n-1, 0, n/2 + 1);
	
	--and or logic 
    type and_small_array is array(0 to n/2 + 1) of std_logic_vector(2*input_data_width-1 downto 0); 
    type and_array is array(0 to 1000) of and_small_array;
    signal and_gate : and_array;
    type or_array is array(0 to comb_length) of std_logic_vector(2*input_data_width-1 downto 0); 
    signal or_gate : or_array;            
begin

    input_divide: for i in 0 to n-1 generate
        inputs_s(n -1 -i) <= input_i((n*2*input_data_width-1)-(i*2*input_data_width) downto ((n-1-i)*2*input_data_width));
    end generate;
     
     voter_and1_logic: for i in 0 to comb_length -1 generate   --bice onoliko AND kapija koliko ima kombinacija
        and_gate(i)(0) <= (others => '1'); --neutral element
        voter_and2_logic: for j in 0 to n/2 generate  --svaka kombinacija ima n/2 + 1 clanova
            and_gate(i)(j+1) <= inputs_s(comb(i)(j)) and and_gate(i)(j);
        end generate;
     end generate;
     
     process(and_gate, or_gate)
     begin
         or_gate(0) <= (others => '0'); --neutral element
         voter_or1_logic: for i in 0 to comb_length - 1 loop --za svaku kombinaciju treba odraditi OR
            or_gate(i+1) <= and_gate(i)(n/2 + 1) or or_gate(i);
         end loop;
     end process;
     
     
     output_o <= or_gate(comb_length);
     
--    voter_and_logic: for i in 0 to 2*input_data_width-1 generate    --which bit
--            voter_or_logic: for j in 1 to n-1 generate  
--            --which redundant modul
--                sum_s[i][j-1] <= std_logic_vector(unsigned(sum_s[j]) + unsigned(inputs_s[j](i)));
--            end generate;
--    end generate;
   
--    process(inputs_s) is 
--        variable output :std_logic_vector(log2c(n)-1+1 downto 0) := ( others => '0' );
--    begin 
--        for j in 0 to n-1 loop
--            sum_s[i] <= std_logic_vector(unsigned(sum_s[i]) + unsigned(inputs_s[j][i]));
--           -- output := output + unsigned(inputs_s[j][i]);
--        end loop;
--    end process;

end behavioral;