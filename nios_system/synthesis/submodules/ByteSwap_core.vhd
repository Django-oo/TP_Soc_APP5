library ieee;
use ieee.std_logic_1164.all;

entity ByteSwap_core is
  port (
    data_in  : in  std_logic_vector(31 downto 0);
    data_out : out std_logic_vector(31 downto 0)
  );
end entity ByteSwap_core;

architecture rtl of ByteSwap_core is
begin
  data_out <= data_in(7 downto 0) &
              data_in(15 downto 8) &
              data_in(23 downto 16) &
              data_in(31 downto 24);
end architecture rtl;
