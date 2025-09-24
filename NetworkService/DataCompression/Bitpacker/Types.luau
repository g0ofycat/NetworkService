--!strict

--=======================
-- // TYPES
--=======================

export type PackableValue = string | number | boolean | PackableTable
export type PackableTable = { [PackableValue]: PackableValue }

return nil