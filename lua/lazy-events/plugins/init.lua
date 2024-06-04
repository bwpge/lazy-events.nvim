require("lazy-events").init()

-- we don't actually need to return any plugin details, we just need a way to
-- get lazy to run the above function before user plugin specs are loaded
return {}
