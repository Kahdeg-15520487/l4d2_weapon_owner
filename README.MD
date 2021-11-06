# Weapon owner plugin for L4D2
Cvar | Description | Default
---|---|---
weapon_owner_on | Enable plugin. 1=Plugin On. 0=Plugin Off | 1
weapon_owner_lock_primary_on | 1=lock Primary weapon On. 0=ignore Primary weapon | 1
weapon_owner_lock_secondary_on | 1=lock Secondary weapon On. 0=ignore Secondary weapon | 1
weapon_owner_lock_timeout | 1=enable Weapon Ownership timeout. 0=disable Weapon Ownership timeout | 0
weapon_owner_lock_timeout_duration | Duration for weapon claim. | 30

Command | Description
---|---
sm_wp_toggle_lock | Toggle on using weapon owner or not.
sm_wp_unlock | Unlock currently claimed weapon.
sm_wp_unlock_primary | Unlock currently claimed primary weapon.
sm_wp_unlock_secondary | Unlock currently claimed secondary weapon.