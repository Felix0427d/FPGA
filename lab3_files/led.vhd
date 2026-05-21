library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity led is
    port (
        clk   : in std_logic;
        btn   : in std_logic; -- Ajout du bouton (souvent sur la broche 10 ou via contrainte)
        led_r : out std_logic;
        led_g : out std_logic;
        led_b : out std_logic
    );
end entity led;

architecture rtl of led is
    -- Pour 2 Hz EXACTEMENT avec une horloge de 12 MHz :
    -- On veut un cycle complet (ON + OFF) en 0.5s.
    -- La LED doit changer d'état tous les 0.25s (soit 3 000 000 de cycles).
    -- log2(3 000 000) = ~21.5, donc un compteur de 22 bits suffit.
    signal counter_g : unsigned(21 downto 0) := (others => '0');
    signal reg_led_g : std_logic := '0';
    
    -- Compteur simple pour la LED Rouge (ton code original)
    signal counter_r : unsigned(20 downto 0) := (others => '0');
begin

    -- STRUCTURE OPEN-DRAIN (Nécessaire sur pico-ice)
    -- '0' allume la LED, 'Z' (haute impédance) l'éteint.
    led_r <= '0' when counter_r(counter_r'high) = '1' else 'Z';
    led_g <= '0' when reg_led_g = '1' else 'Z';
    -- La LED bleue s'allume quand on appuie sur le bouton
    led_b <= '0' when btn = '1' else 'Z';

    process (clk)
    begin
        if rising_edge(clk) then
            -- Gestion de la LED Rouge (libre)
            counter_r <= counter_r + 1;

            -- Gestion de la LED Verte + Bouton
            if btn = '1' then
                counter_g <= (others => '0'); -- Clear le compteur
                reg_led_g <= '0';             -- Éteint la LED verte
            else
                if counter_g = 2999999 then   -- 3 millions de cycles (0.25s)
                    counter_g <= (others => '0');
                    reg_led_g <= not reg_led_g; -- Toggle l'état
                else
                    counter_g <= counter_g + 1;
                end if;
            end if;
        end if;
    end process;

end architecture;