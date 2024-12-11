package main

import (
	"github.com/tonymet/gcloud-go/misc"
	"testing"
)

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
			if got := misc.IncrementVersion(tt.args.v); got != tt.want {
				t.Errorf("incrementVersion() = %v, want %v", got, tt.want)
			}
		})
	}
}

func Test_getObjectContents(t *testing.T) {
	type args struct {
		bucket string
		object string
	}
	tests := []struct {
		name string
		args args
		want string
	}{
		{
			"test1",
			args{"tonym.us", "gcloud-lite/version-test"},
			"474.0.0",
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := misc.GetObjectContents(tt.args.bucket, tt.args.object); got != tt.want {
				t.Errorf("getObjectContents() = %v, want %v", got, tt.want)
			}
		})
	}
}
