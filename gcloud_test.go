package main

import "testing"

func Test_incrementVersion(t *testing.T) {
	type args struct {
		v string
	}
	tests := []struct {
		name string
		args args
		want string
	}{{
		"test1",
		args{"474.0.0"},
		"475.0.0",
		// TODO: Add test cases.
	}}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := incrementVersion(tt.args.v); got != tt.want {
				t.Errorf("incrementVersion() = %v, want %v", got, tt.want)
			}
		})
	}
}
