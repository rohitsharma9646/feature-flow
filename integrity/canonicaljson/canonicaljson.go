// Package canonicaljson implements the deliberately narrow canonical JSON
// profile used by the integrity protocol. It accepts only JSON-native values,
// rejects floating point values, sorts object keys bytewise, and preserves
// array order.
package canonicaljson

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"reflect"
	"sort"
	"strconv"
	"unicode/utf8"
)

func Marshal(value any) ([]byte, error) {
	var out bytes.Buffer
	if err := appendValue(&out, value); err != nil {
		return nil, err
	}
	return out.Bytes(), nil
}

func appendValue(out *bytes.Buffer, value any) error {
	switch item := value.(type) {
	case nil:
		out.WriteString("null")
	case bool:
		out.WriteString(strconv.FormatBool(item))
	case string:
		if !utf8.ValidString(item) {
			return errors.New("canonical JSON string is not valid UTF-8")
		}
		raw, err := marshalString(item)
		if err != nil {
			return err
		}
		out.Write(raw)
	case int:
		out.WriteString(strconv.Itoa(item))
	case int64:
		out.WriteString(strconv.FormatInt(item, 10))
	case uint:
		out.WriteString(strconv.FormatUint(uint64(item), 10))
	case uint64:
		out.WriteString(strconv.FormatUint(item, 10))
	case json.Number:
		if _, err := strconv.ParseInt(item.String(), 10, 64); err != nil {
			return errors.New("canonical JSON accepts integer numbers only")
		}
		out.WriteString(item.String())
	case []string:
		values := make([]any, len(item))
		for i := range item {
			values[i] = item[i]
		}
		return appendValue(out, values)
	case []any:
		out.WriteByte('[')
		for i := range item {
			if i != 0 {
				out.WriteByte(',')
			}
			if err := appendValue(out, item[i]); err != nil {
				return err
			}
		}
		out.WriteByte(']')
	case map[string]string:
		values := make(map[string]any, len(item))
		for key, value := range item {
			values[key] = value
		}
		return appendValue(out, values)
	case map[string]any:
		keys := make([]string, 0, len(item))
		for key := range item {
			if !utf8.ValidString(key) {
				return errors.New("canonical JSON key is not valid UTF-8")
			}
			keys = append(keys, key)
		}
		sort.Strings(keys)
		out.WriteByte('{')
		for i, key := range keys {
			if i != 0 {
				out.WriteByte(',')
			}
			raw, err := marshalString(key)
			if err != nil {
				return err
			}
			out.Write(raw)
			out.WriteByte(':')
			if err := appendValue(out, item[key]); err != nil {
				return fmt.Errorf("%s: %w", key, err)
			}
		}
		out.WriteByte('}')
	default:
		kind := reflect.TypeOf(value)
		if kind == nil {
			return errors.New("unsupported canonical JSON value")
		}
		return fmt.Errorf("unsupported canonical JSON type %s", kind)
	}
	return nil
}

func marshalString(value string) ([]byte, error) {
	var out bytes.Buffer
	encoder := json.NewEncoder(&out)
	encoder.SetEscapeHTML(false)
	if err := encoder.Encode(value); err != nil {
		return nil, err
	}
	raw := out.Bytes()
	return raw[:len(raw)-1], nil
}
