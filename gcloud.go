package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"log"
	"os"
	"path"
	"strconv"
	"strings"
	"time"

	"cloud.google.com/go/pubsub"
	"cloud.google.com/go/storage"
	"github.com/google/go-github/v67/github"
	"google.golang.org/api/iterator"
)

func logErr(format string, params ...any) {
	if len(params) > 0 {
		fmt.Fprintf(os.Stderr, format, params...)
	} else {
		fmt.Fprint(os.Stderr, format)
	}
}

type buildCommand struct {
	Command string `json:"command"`
	Version string `json:"cloud_sdk_version"`
}

func (bc buildCommand) toJson() ([]byte, error) {
	if b, err := json.Marshal(bc); err != nil {
		return []byte{}, err
	} else {
		return b, nil
	}
}

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
		logErr("name: %s\n", attrs.Name)
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
func getObjectStdout(bucket, object string) {
	ctx := context.Background()
	ctx, cancel := context.WithTimeout(ctx, time.Minute)
	defer cancel()
	obj := getObject(ctx, bucket, object)
	if r, err := obj.NewReader(ctx); err != nil {
		panic(err)
	} else {
		io.Copy(os.Stdout, r)
	}
}

func getObjectContents(bucket, object string) string {
	ctx := context.Background()
	ctx, cancel := context.WithTimeout(ctx, time.Minute)
	defer cancel()
	obj := getObject(ctx, bucket, object)
	r, err := obj.NewReader(ctx)
	if err != nil {
		panic(err)
	}
	var result strings.Builder
	io.Copy(&result, r)
	return result.String()
}

func getObject(ctx context.Context, bucket, object string) *storage.ObjectHandle {
	client, err := storage.NewClient(ctx)
	if err != nil {
		panic(err)
	}
	defer client.Close()
	bkt := client.Bucket(bucket)
	return bkt.Object(object)
}

func syncUp() {}

func pubsubPushBuild(project, v string) {
	ctx := context.Background()
	ctx, cancel := context.WithTimeout(ctx, time.Minute)
	defer cancel()
	c, err := pubsub.NewClient(ctx, project)
	if err != nil {
		panic(err)
	}
	defer c.Close()
	t := c.Topic("gcloud-lite")
	defer t.Stop()
	bc := buildCommand{"docker-build", v}
	if bcMarshalled, err := bc.toJson(); err != nil {
		panic(err)
	} else {
		pr := t.Publish(ctx, &pubsub.Message{Data: bcMarshalled})
		if _, err := pr.Get(ctx); err != nil {
			panic(err)
		}
		logErr("publish complete. message = %s", string(bcMarshalled))
	}
}

func incrementVersion(v string) string {
	major := strings.Split(v, ".")
	if val, err := strconv.ParseInt(major[0], 10, 32); err != nil {
		panic(err)
	} else {
		return fmt.Sprintf("%d.0.0", val+1)
	}
}

func getActiveVersion(bucket, object string) string {
	return incrementVersion(getObjectContents(bucket, object))
}

func githubRelease(args githubArgs) {
	owner, repo, file, commit := args.owner, args.repo, args.file, args.commit
	var tagValue string
	if args.tag != "" {
		tagValue = args.tag
	} else {
		tagValue = time.Now().Format(time.DateOnly) + "-" + commit[0:7]
	}
	ctx := context.Background()
	client := github.NewClient(nil).WithAuthToken(os.Getenv("GH_TOKEN"))
	r := &github.RepositoryRelease{
		TagName:         &tagValue,
		TargetCommitish: &commit,
	}
	if _, res, err := client.Repositories.GetReleaseByTag(ctx, owner, repo, tagValue); res != nil && res.StatusCode == 200 {
		logErr("Release already exists, skipping\n")
		os.Exit(0)
	} else if (res != nil && res.StatusCode != 404) || (err != nil && res == nil) {
		panic(err)
	}
	if repoObj, _, err := client.Repositories.CreateRelease(ctx, owner, repo, r); err != nil {
		panic(err)
	} else if fileHandle, err := os.Open(file); err != nil {
		panic(err)
	} else if asset, _, err := client.Repositories.UploadReleaseAsset(ctx, owner, repo, *repoObj.ID, &github.UploadOptions{Name: path.Base(file)}, fileHandle); err != nil {
		panic(err)
	} else {
		logErr("release ID: %+d\n", repoObj.ID)
		logErr("asset ID: %+x\n", asset.ID)
	}
}

func init() {
	cmdGithubRelease = flag.NewFlagSet("github-release", flag.ExitOnError)
	cmdGithubRelease.StringVar(&cmdArgsGithub.repo, "repo", "", "name of repo")
	cmdGithubRelease.StringVar(&cmdArgsGithub.owner, "owner", "", "name of user")
	cmdGithubRelease.StringVar(&cmdArgsGithub.file, "file", "", "path to file")
	cmdGithubRelease.StringVar(&cmdArgsGithub.commit, "commit", "", "full commit sha")
	cmdGithubRelease.StringVar(&cmdArgsGithub.tag, "tag", "", "tag")
}

var (
	cmdGithubRelease *flag.FlagSet
	cmdArgsGithub    githubArgs
)

type githubArgs struct {
	owner, repo, commit, file, tag string
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
		fmt.Printf("%s\n", getActiveVersion(os.Args[2], os.Args[3]))
	case "get-object":
		getObjectStdout(os.Args[2], os.Args[3])
	case "pub-sub-build":
		pubsubPushBuild(os.Args[2], os.Args[3])
	case "github-release":
		cmdGithubRelease.Parse(os.Args[2:])
		githubRelease(cmdArgsGithub)
	default:
		panic(fmt.Errorf("invalid argument %s ", os.Args[1]))
	}
}
