  -- =============================================================================                             -- mcLaw - Shared Constants & Utilities
  -- Loaded on both client and server side.                                                                    -- All enums mirror the ENUM values defined in install.sql exactly.
  -- Use these constants instead of raw strings to avoid typos and make
  -- refactoring easier - if a DB enum ever changes, update it here only.
  -- =============================================================================

  Mclaw = Mclaw or {}

  -- =============================================================================
  -- FILE STATUS ENUM
  -- Represents the lifecycle stage of a legal file (mclaw_files.status).
  --
  --   OPENED               - File has just been created, no prosecutor yet.
  --   AWAITING_PROSECUTOR  - Waiting for a prosecutor to be assigned.
  --   PROSECUTOR_REVIEW    - Assigned prosecutor is reviewing the file.
  --   INDICTMENT_READY     - Prosecutor has prepared the indictment.
  --   HEARING_SCHEDULED    - A court hearing date has been set.
  --   WRITTEN_TRIAL_ACTIVE - Trial is ongoing via the written panel (no physical hearing).
  --   VERDICT_ISSUED       - Judge has issued a final verdict.
  --   ENFORCEMENT_ACTIVE   - Post-verdict enforcement (confiscation, fines) is in progress.
  --   CLOSED               - File is fully resolved and closed.
  --   ARCHIVED             - File is archived for record-keeping, no further actions allowed.
  -- =============================================================================
  Mclaw.FileStatus = {
      OPENED               = 'opened',
      AWAITING_PROSECUTOR  = 'awaiting_prosecutor',
      PROSECUTOR_REVIEW    = 'prosecutor_review',
      INDICTMENT_READY     = 'indictment_ready',
      HEARING_SCHEDULED    = 'hearing_scheduled',
      WRITTEN_TRIAL_ACTIVE = 'written_trial_active',
      VERDICT_ISSUED       = 'verdict_issued',
      ENFORCEMENT_ACTIVE   = 'enforcement_active',
      CLOSED               = 'closed',
      ARCHIVED             = 'archived',
  }

  -- =============================================================================
  -- FILE TYPE ENUM
  -- Represents the nature/stage of the legal process for a file (mclaw_files.type).
  --
  --   INVESTIGATION  - Early stage; suspect is being investigated, no formal charges filed yet.
  --   CASE           - Formal case opened; indictment exists, heading toward a hearing.
  --   WRITTEN_TRIAL  - Trial conducted entirely through the system panel, no physical courtroom.
  -- =============================================================================
  Mclaw.FileType = {
      INVESTIGATION = 'investigation',
      CASE          = 'case',
      WRITTEN_TRIAL = 'written_trial',
  }

  -- =============================================================================
  -- VERDICT RESULT ENUM
  -- The outcome of a judge's final decision (mclaw_verdicts.result).
  --
  --   GUILTY    - Defendant is found guilty; jail time and/or fine is applied.
  --   ACQUITTED - Defendant is found not guilty; compensation may be triggered if enabled.
  --   DISMISSED - Case is dropped without a guilty/not-guilty ruling (e.g. lack of evidence).
  -- =============================================================================
  Mclaw.VerdictResult = {
      GUILTY    = 'guilty',
      ACQUITTED = 'acquitted',
      DISMISSED = 'dismissed',
  }

  -- =============================================================================
  -- WARRANT TYPE ENUM
  -- The type of legal warrant issued by a judge (mclaw_warrants.type).
  --
  --   ARREST  - Authorises police to apprehend and detain the suspect.
  --   SEARCH  - Authorises police to search a property or vehicle.
  --   SEIZURE - Authorises the seizure (confiscation) of an asset.
  -- =============================================================================
  Mclaw.WarrantType = {
      ARREST  = 'arrest',
      SEARCH  = 'search',
      SEIZURE = 'seizure',
  }

  -- =============================================================================
  -- HEARING TYPE ENUM
  -- How the court hearing is conducted (mclaw_hearings.type).
  --
  --   PHYSICAL - Held at a real in-game location (coordinates defined by the judge).
  --   WRITTEN  - Conducted entirely through the system panel; no physical presence required.
  -- =============================================================================
  Mclaw.HearingType = {
      PHYSICAL = 'physical',
      WRITTEN  = 'written',
  }

  -- =============================================================================
  -- HEARING STATUS ENUM
  -- Lifecycle of a scheduled hearing (mclaw_hearings.status).
  --
  --   SCHEDULED  - Hearing is planned but has not started yet.
  --   ACTIVE     - Hearing is currently in progress.
  --   COMPLETED  - Hearing concluded normally.
  --   CANCELLED  - Hearing was cancelled before it started.
  -- =============================================================================
  Mclaw.HearingStatus = {
      SCHEDULED = 'scheduled',
      ACTIVE    = 'active',
      COMPLETED = 'completed',
      CANCELLED = 'cancelled',
  }

  -- =============================================================================
  -- JAIL DECISION ENUM
  -- The suspect's response to the jail entry panel (mclaw_jail_decisions.decision).
  --
  --   PENDING  - Suspect has not yet interacted with the panel.
  --   ACCEPTED - Suspect accepted the charges; sentence begins immediately.
  --   REJECTED - Suspect denied the charges; a legal file is opened automatically.
  -- =============================================================================
  Mclaw.JailDecision = {
      PENDING  = 'pending',
      ACCEPTED = 'accepted',
      REJECTED = 'rejected',
  }

  -- =============================================================================
  -- ATTORNEY SCOPE ENUM
  -- How broad a power of attorney is (mclaw_attorneys.scope).
  --
  --   GENERAL    - The lawyer can represent the client across all their files.
  --   FILE_BASED - The lawyer can only act on behalf of the client for one specific file.
  -- =============================================================================
  Mclaw.AttorneyScope = {
      GENERAL    = 'general',
      FILE_BASED = 'file_based',
  }

  -- =============================================================================
  -- EVIDENCE TYPE ENUM
  -- The format of an evidence entry (mclaw_evidence.type).
  --
  --   TEXT       - Free-text description (e.g. witness statement, officer note).
  --   SCREENSHOT - A URL pointing to an image (e.g. Discord CDN link).
  --   COORDINATE - An in-game location stored as JSON: {"x":0.0,"y":0.0,"z":0.0,"label":"..."}
  --   ITEM       - A reference to an inventory item: {"item":"weapon_pistol","count":1,"serial":"..."}
  --   STASH      - A reference to an ox_inventory evidence stash: {"stash_id":"...","slot":1}
  -- =============================================================================
  Mclaw.EvidenceType = {
      TEXT       = 'text',
      SCREENSHOT = 'screenshot',
      COORDINATE = 'coordinate',
      ITEM       = 'item',
      STASH      = 'stash',
  }

  -- =============================================================================
  -- ASSET TYPE ENUM
  -- The type of asset being confiscated (mclaw_confiscations.asset_type).
  --
  --   VEHICLE  - A registered vehicle identified by its plate number.
  --   PROPERTY - A property identified by its property ID.
  --   CASH     - Physical cash amount.
  --   BANK     - Bank account funds.
  --   ITEM     - A specific inventory item.
  -- =============================================================================
  Mclaw.AssetType = {
      VEHICLE  = 'vehicle',
      PROPERTY = 'property',
      CASH     = 'cash',
      BANK     = 'bank',
      ITEM     = 'item',
  }

  -- =============================================================================
  -- CHARGE CATEGORY ENUM
  -- The legal category of a criminal charge (mclaw_charges_config.category).
  -- Used for UI grouping and filtering in panels.
  --
  --   VIOLENCE - Crimes involving physical harm or threat (assault, murder, etc.).
  --   PROPERTY - Crimes against property (theft, vandalism, burglary, etc.).
  --   DRUG     - Drug-related offences (possession, trafficking, etc.).
  --   TRAFFIC  - Traffic violations (speeding, DUI, hit-and-run, etc.).
  --   OTHER    - Any charge that does not fit the above categories.
  -- =============================================================================
  Mclaw.ChargeCategory = {
      VIOLENCE = 'violence',
      PROPERTY = 'property',
      DRUG     = 'drug',
      TRAFFIC  = 'traffic',
      OTHER    = 'other',
  }

  -- =============================================================================
  -- GetChargeByCode(code)
  -- Looks up a charge definition from Config.Charges.list by its unique code.
  -- Returns the charge table { code, label, category, jailTime, fine, severity }
  -- or nil if no charge with that code exists.
  --
  -- Usage:
  --   local charge = Mclaw.GetChargeByCode('armed_assault')
  --   if charge then print(charge.label, charge.jailTime) end
  -- =============================================================================
  function Mclaw.GetChargeByCode(code)
      for _, charge in ipairs(Config.Charges.list) do
          if charge.code == code then
              return charge
          end
      end
      return nil
  end

  -- =============================================================================
  -- FormatFileNumber(year, sequence)
  -- Generates a formatted file number string from a year and a numeric sequence.
  -- Format is defined by Config.FileNumber: {prefix}-{year}-{zero-padded sequence}
  --
  -- Parameters:
  --   year     (number) -- the calendar year, e.g. 2026
  --   sequence (number) -- the auto-increment sequence for that year, e.g. 42
  --
  -- Returns:
  --   string -- e.g. "MCL-2026-00042" (with default prefix "MCL" and padWidth 5)
  --
  -- Usage:
  --   local num = Mclaw.FormatFileNumber(2026, 42)  --> "MCL-2026-00042"
  -- =============================================================================
  function Mclaw.FormatFileNumber(year, sequence)
      local padded = string.format('%0' .. Config.FileNumber.padWidth .. 'd', sequence)
      return Config.FileNumber.prefix .. '-' .. year .. '-' .. padded
  end

  -- =============================================================================
  -- CalculateSentence(charges)
  -- Sums up the total jail time and fine for a list of charges.
  -- Respects per-charge overrides set by the judge (jail_override / fine_override).
  -- Falls back to Config.Charges defaults when no override is present.
  --
  -- Parameters:
  --   charges (table) -- array of charge entries, each with:
  --     .code          (string)     -- charge code, looked up in Config.Charges.list
  --     .jail_override (number|nil) -- judge-set jail time in minutes; nil = use default
  --     .fine_override (number|nil) -- judge-set fine amount; nil = use default
  --
  -- Returns:
  --   table -- { jailTime = <total minutes>, fine = <total amount> }
  --            Both values are 0 if the charge list is empty or all codes are unknown.
  --
  -- Usage:
  --   local sentence = Mclaw.CalculateSentence({
  --       { code = 'armed_assault' },
  --       { code = 'theft', jail_override = 10, fine_override = 1000 },
  --   })
  --   -- sentence.jailTime -> 70  (60 + 10)
  --   -- sentence.fine     -> 6000 (5000 + 1000)
  -- =============================================================================
  function Mclaw.CalculateSentence(charges)
      local totalJail = 0
      local totalFine = 0

      for _, entry in ipairs(charges) do
          local def = Mclaw.GetChargeByCode(entry.code)
          if def then
              totalJail = totalJail + (entry.jail_override ~= nil and entry.jail_override or def.jailTime)
              totalFine = totalFine + (entry.fine_override ~= nil and entry.fine_override or def.fine)
          end
      end

      return { jailTime = totalJail, fine = totalFine }
  end