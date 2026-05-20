library ieee;
use ieee.std_logic_1164.all;

entity ByteSwap_avalon_interface is
  port (
    clock      : in  std_logic;
    reset_n    : in  std_logic;
    address    : in  std_logic_vector(0 downto 0);
    read       : in  std_logic;
    write      : in  std_logic;
    chipselect : in  std_logic;
    writedata  : in  std_logic_vector(31 downto 0);
    byteenable : in  std_logic_vector(3 downto 0);
    readdata   : out std_logic_vector(31 downto 0)
  );
end entity ByteSwap_avalon_interface;

architecture rtl of ByteSwap_avalon_interface is
  signal input_reg : std_logic_vector(31 downto 0);
  signal swapped   : std_logic_vector(31 downto 0);
begin
  swapped <= input_reg(7 downto 0) &
             input_reg(15 downto 8) &
             input_reg(23 downto 16) &
             input_reg(31 downto 24);

  process (clock, reset_n)
  begin
    if reset_n = '0' then
      input_reg <= (others => '0');
    elsif rising_edge(clock) then
      if chipselect = '1' and write = '1' and address = "0" then
        if byteenable(0) = '1' then
          input_reg(7 downto 0) <= writedata(7 downto 0);
        end if;
        if byteenable(1) = '1' then
          input_reg(15 downto 8) <= writedata(15 downto 8);
        end if;
        if byteenable(2) = '1' then
          input_reg(23 downto 16) <= writedata(23 downto 16);
        end if;
        if byteenable(3) = '1' then
          input_reg(31 downto 24) <= writedata(31 downto 24);
        end if;
      end if;
    end if;
  end process;

  process (address, chipselect, read, input_reg, swapped)
  begin
    readdata <= (others => '0');
    if chipselect = '1' and read = '1' then
      case address is
        when "0" =>
          readdata <= swapped;
        when others =>
          readdata <= input_reg;
      end case;
    end if;
  end process;
end architecture rtl;
