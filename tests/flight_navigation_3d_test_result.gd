extends RefCounted
class_name FlightNavigation3DTestResult

func all_passed() -> bool: 
	var result = true
	for case in case_log.keys():
		result = result and case_log[case]
	return result

## Dictionary[Test case name, message]
var case_log: Dictionary[String, bool] = {}
var case_log_message: Dictionary[String, String] = {}

func write_case(case_name: String, result: bool):
	if result:
		case_log_message[case_name] = "passed"
	else:
		case_log_message[case_name] = "failed"
	case_log[case_name] = result

func to_json() -> Dictionary:
	return {
		"passed": all_passed(),
		"case_log": case_log_message,
	}
