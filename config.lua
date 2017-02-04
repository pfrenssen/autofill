--luacheck: globals AF DEBUG

AF = {
    DEBUG = true
}

AF.control = {
    loglevel = 2, --Default: 0, Minimum level to show log messages, 0=off, 1=logfile, 2=logfile and print
    make_default_fill_sets = true, --Default: true, Use pre-defined default fill_sets
    make_default_item_sets = true, --Default: true, Use pre-defined default item_sets
    make_item_sets_from_prototypes = false, --Default: true, Dynamically create global item_sets based on item categories
}

--Debug related testing settings.
AF.quickstart = {
    clear_items = true,
    power_armor = true,
    destroy_everything = true,
    floor_tile = "concrete",
    stacks = {
        "blueprint",
        "deconstruction-planner",
        "creative-mode_matter-source",
        "creative-mode_fluid-source",
        "creative-mode_energy-source",
        "creative-mode_super-electric-pole",
        "construction-robot",
        "creative-mode_magic-wand-modifier",
        "stone-furnace",
        "solid-fuel",
    },
}

return AF
