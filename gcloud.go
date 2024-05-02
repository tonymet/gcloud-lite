package main

import (
	"context"
	"fmt"
	"io"
	"log"
	"os"
	"strconv"
	"strings"
	"time"

	"cloud.google.com/go/pubsub"
	"cloud.google.com/go/storage"
	"google.golang.org/api/iterator"
)

// uploadFile uploads an object.
func setObject(bucket, object, contents string) error {
	ctx := context.Background()
	client, err := storage.NewClient(ctx)
	if err != nil {
		panic(err)
	}
	defer client.Close()
	ctx, cancel := context.WithTimeout(ctx, time.Minute)
	defer cancel()
	f := strings.NewReader(contents)
	o := client.Bucket(bucket).Object(object)
	//o = o.If(storage.Conditions{DoesNotExist: true})
	wc := o.NewWriter(ctx)
	if _, err = io.Copy(wc, f); err != nil {
		panic(err)
	}
	if err := wc.Close(); err != nil {
		panic(err)
	}
	return nil
}

func syncDown(bucket, prefix string) {
	ctx := context.Background()
	ctx, cancel := context.WithTimeout(ctx, time.Minute)
	defer cancel()
	client, err := storage.NewClient(ctx)
	if err != nil {
		panic(err)
	}
	defer client.Close()
	bkt := client.Bucket(bucket)
	query := &storage.Query{Prefix: prefix}
	it := bkt.Objects(ctx, query)
	for {
		attrs, err := it.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			log.Fatal(err)
		}
		fmt.Printf("name: %s\n", attrs.Name)
		switch {
		case strings.HasSuffix(attrs.Name, "/"):
			if err := os.MkdirAll(attrs.Name, 0750); err != nil {
				panic(err)
			}
		default:
			if h, err := bkt.Object(attrs.Name).NewReader(ctx); err != nil {
				panic(err)
			} else if f, err := os.Create(attrs.Name); err != nil {
				panic(err)
			} else if _, err := io.Copy(f, h); err != nil {
				panic(err)
			}
		}
	}
}
func getObject(bucket, object string) {
	ctx := context.Background()
	ctx, cancel := context.WithTimeout(ctx, time.Minute)
	defer cancel()
	client, err := storage.NewClient(ctx)
	if err != nil {
		panic(err)
	}
	defer client.Close()
	bkt := client.Bucket(bucket)
	obj := bkt.Object(object)
	if r, err := obj.NewReader(ctx); err != nil {
		panic(err)
	} else {
		io.Copy(os.Stdout, r)
	}
}

func syncUp() {}

func pubsubPushBuild(v string) {
	ctx := context.Background()
	ctx, cancel := context.WithTimeout(ctx, time.Minute)
	defer cancel()
	c, err := pubsub.NewClient(ctx, "tonym-us")
	if err != nil {
		panic(err)
	}
	defer c.Close()
	t := c.Topic("gcloud-lite")
	defer t.Stop()
	t.Publish(ctx, &pubsub.Message{Data: []byte("{\"command\": \"docker-build\", \"cloud_sdk_version\": \"" + v + "\"}")})
}

func incrementVersion(v string) string {
	major := strings.Split(v, ".")
	if val, err := strconv.ParseInt(major[0], 10, 32); err != nil {
		panic(err)
	} else {
		return fmt.Sprintf("%d.0.0", val+1)
	}
}

func main() {
	switch os.Args[1] {
	case "set-object":
		setObject(os.Args[2], os.Args[3], os.Args[4])
	case "sync-up":
		syncUp()
	case "sync-down":
		syncDown(os.Args[2], os.Args[3])
	case "active-version":
		fmt.Printf("%s\n", incrementVersion("474.0.0"))
	case "get-object":
		getObject(os.Args[2], os.Args[3])
	case "pub-sub-build":
		pubsubPushBuild(os.Args[2])
	default:
		panic(fmt.Sprintf("invalid argument %s ", os.Args[1]))
	}
}
