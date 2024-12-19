package main

import (
	"flag"
	"fmt"
	"mime"
	"os"

	"github.com/tonymet/gcloud-go/github"
	"github.com/tonymet/gcloud-go/kms"
	"github.com/tonymet/gcloud-go/misc"
	_ "golang.org/x/crypto/x509roots/fallback"
)

func init() {
	cmdGithubRelease = flag.NewFlagSet("github-release", flag.ExitOnError)
	cmdGithubRelease.StringVar(&cmdArgsGithub.Repo, "repo", "", "name of repo")
	cmdGithubRelease.StringVar(&cmdArgsGithub.Owner, "owner", "", "name of user")
	cmdGithubRelease.StringVar(&cmdArgsGithub.File, "file", "", "path to file")
	cmdGithubRelease.StringVar(&cmdArgsGithub.Commit, "commit", "", "full commit sha")
	cmdGithubRelease.StringVar(&cmdArgsGithub.Tag, "tag", "", "tag")
	cmdGithubRelease.StringVar(&cmdArgsGithub.KeyPath, "k", "", "kms keypath")
	cmdKMS = flag.NewFlagSet("kms-sign", flag.ExitOnError)
	mime.AddExtensionType(".sig", "application/octet-stream")
	mime.AddExtensionType(".gz", "application/x-gtar-compressed")
	mime.AddExtensionType(".tar.gz", "application/x-gtar-compressed")
}

var (
	cmdGithubRelease *flag.FlagSet
	cmdKMS           *flag.FlagSet
	cmdArgsGithub    github.GithubArgs
	cmdArgsKMS       misc.KMSArgs
	//keyPath          = "projects/dev-tonym-us/locations/us-west0/keyRings/test-software-signing/cryptoKeys/cloud-lite-signing/cryptoKeyVersions/1"
)

func main() {
	switch os.Args[1] {
	case "set-object":
		misc.SetObject(os.Args[2], os.Args[3], os.Args[4])
	case "sync-down":
		misc.SyncDown(os.Args[2], os.Args[3])
	case "active-version":
		fmt.Printf("%s\n", misc.GetActiveVersion(os.Args[2], os.Args[3]))
	case "get-object":
		misc.GetObjectStdout(os.Args[2], os.Args[3])
	case "pub-sub-build":
		misc.PubsubPushBuild(os.Args[2], os.Args[3])
	case "github-release":
		cmdArgsGithub.Token = os.Getenv("GH_TOKEN")
		cmdGithubRelease.Parse(os.Args[2:])
		err := misc.GithubRelease(cmdArgsGithub)
		if err != nil {
			panic(err)
		}
	case "kms-sign":
		cmdKMS.Parse(os.Args[2:])
		signAsymmetricExec(cmdArgsKMS)
	default:
		panic(fmt.Errorf("invalid argument %s ", os.Args[1]))
	}
}

func signAsymmetricExec(args misc.KMSArgs) {
	// setup in & out
	outputWriter, err := os.Create(args.Output)
	if err != nil {
		panic(err)
	}
	defer outputWriter.Close()
	inputReader, err := os.Open(args.Filename)
	if err != nil {
		panic(err)
	}
	defer inputReader.Close()
	err = kms.SignAsymmetric(outputWriter, args.Keypath, inputReader)
	if err != nil {
		panic(err)
	}

}
