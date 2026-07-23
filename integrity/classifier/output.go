package classifier

import "encoding/json"

// MarshalResult returns the canonical protocol line.
func MarshalResult(result Result) ([]byte, error) {
	data, err := json.Marshal(result)
	if err != nil {
		return nil, err
	}
	return append(data, '\n'), nil
}
