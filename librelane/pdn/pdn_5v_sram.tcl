# SRAM macros for Data_RAM (NS oriented)

set sram_instances [list \
    i_chip_core.core_inst.axi_top.ram_slave.data_ram.sram_b0_s0 \
    i_chip_core.core_inst.axi_top.ram_slave.data_ram.sram_b0_s1 \
    i_chip_core.core_inst.axi_top.ram_slave.data_ram.sram_b0_s2 \
    i_chip_core.core_inst.axi_top.ram_slave.data_ram.sram_b0_s3 \
    i_chip_core.core_inst.axi_top.ram_slave.data_ram.sram_b1_s0 \
    i_chip_core.core_inst.axi_top.ram_slave.data_ram.sram_b1_s1 \
    i_chip_core.core_inst.axi_top.ram_slave.data_ram.sram_b1_s2 \
    i_chip_core.core_inst.axi_top.ram_slave.data_ram.sram_b1_s3 \
]

define_pdn_grid \
    -macro \
    -instances $sram_instances \
    -name sram_macros_NS \
    -starts_with POWER \
    -halo "$::env(PDN_HORIZONTAL_HALO) $::env(PDN_VERTICAL_HALO)"

add_pdn_connect \
    -grid sram_macros_NS \
    -layers "$::env(PDN_VERTICAL_LAYER) $::env(PDN_HORIZONTAL_LAYER)"

add_pdn_connect \
    -grid sram_macros_NS \
    -layers "$::env(PDN_VERTICAL_LAYER) Metal3"

# Add stripes on W/E edges of SRAM
add_pdn_stripe \
    -grid sram_macros_NS \
    -layer Metal4 \
    -width 2.36 \
    -offset 1.18 \
    -spacing 0.28 \
    -pitch 426.86 \
    -starts_with GROUND \
    -number_of_straps 2

# Since the above stripes block the top level PDN at Metal4, add some more stripes
# to improve the PDN's integrity and ensure a better connection for the macro.
add_pdn_stripe \
    -grid sram_macros_NS \
    -layer Metal4 \
    -width 4.00 \
    -offset 65.93 \
    -spacing 0.28 \
    -pitch 50 \
    -starts_with GROUND \
    -number_of_straps 7
