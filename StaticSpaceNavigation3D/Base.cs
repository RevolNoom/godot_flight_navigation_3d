using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;

// Scan buildings in base, and calculate global stats
class Base
{
	private float army_training_speed;
	private float equipment_production_speed;
	
	private float credit_production_speed;
	private float alloy_production_speed;
	
	private float research_speed;
	private float construction_speed;
	
	private float defence_limit;
	private float template_slot;	

	private Building[] buildings;
	private Unit[] unit;
}
