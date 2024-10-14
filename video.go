package main

import (
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"strings"

	"github.com/go-pg/pg/v10"

	"github.com/gin-gonic/gin"
	"gopkg.in/yaml.v3"
)

var dbSession *pg.DB = nil

type Video struct {
	ID    string `json:"id"`
	Title string `json:"title"`
}

func getDB(c *gin.Context) *pg.DB {
	if dbSession != nil {
		return dbSession
	}

	host := os.Getenv("DB_HOST")
	if len(host) == 0 {
		slog.Error("Environment variable `DB_HOST` is empty")
		c.String(http.StatusBadRequest, "Environment variable `DB_HOST` is empty")
		return nil
	}
	port := os.Getenv("DB_PORT")
	if len(port) == 0 {
		port = "5432"
	}
	user := os.Getenv("DB_USER")
	if len(user) == 0 {
		user = os.Getenv("DB_USERNAME")
		if len(user) == 0 {
			slog.Error("Environment variables `DB_USER` and `DB_USERNAME` are empty")
			c.String(http.StatusBadRequest, "Environment variables `DB_USER` and `DB_USERNAME` are empty")
			return nil
		}
	}
	pass := os.Getenv("DB_PASS")
	if len(pass) == 0 {
		pass = os.Getenv("DB_PASSWORD")
		if len(pass) == 0 {
			slog.Error("Environment variables `DB_PASS` and `DB_PASSWORD are empty")
			c.String(http.StatusBadRequest, "Environment variables `DB_PASS` and `DB_PASSWORD are empty")
			return nil
		}
	}
	name := os.Getenv("DB_NAME")
	if len(name) == 0 {
		slog.Error("Environment variable `DB_NAME` is empty")
		c.String(http.StatusBadRequest, "Environment variable `DB_NAME` is empty")
		return nil
	}

	endpoint := fmt.Sprintf("%s:%s", host, port)

	dbSession := pg.Connect(&pg.Options{
		Addr:     endpoint,
		User:     user,
		Password: pass,
		Database: name,
	})

	_, err := dbSession.Exec("SELECT 1")
	if err != nil {
		slog.Error("Failed to connect to the database", "error", err)
		c.String(http.StatusInternalServerError, "Failed to connect to the database")
		return nil
	} else {
		slog.Info("Connected to the database", "endpoint", endpoint, "user", user, "database", name)
	}

	return dbSession
}

func videosGetHandler(ctx *gin.Context) {
	slog.Debug("Handling request", "URI", ctx.Request.RequestURI)
	var videos []Video
	if strings.ToLower(os.Getenv("DB")) == "fs" {
		var err error
		videos, err = getVideosFromFile()
		if err != nil {
			httpErrorInternalServerError(err, ctx)
			return
		}
	} else {
		db := getDB(ctx)
		if db == nil {
			return
		}
		err := db.ModelContext(ctx, &videos).Select()
		if err != nil {
			httpErrorInternalServerError(err, ctx)
			return
		}
	}
	ctx.JSON(http.StatusOK, videos)
}

func getVideosFromFile() ([]Video, error) {
	dir := os.Getenv("FS_DIR")
	if len(dir) == 0 {
		dir = "/cache"
	}
	path := fmt.Sprintf("%s/videos.yaml", dir)
	var videos []Video
	yamlData, err := os.ReadFile(path)
	if err != nil {
		return videos, err
	}
	err = yaml.Unmarshal(yamlData, &videos)
	return videos, err
}

func videoPostHandler(ctx *gin.Context) {
	slog.Debug("Handling request", "URI", ctx.Request.RequestURI)
	id := ctx.Query("id")
	if len(id) == 0 {
		httpErrorBadRequest(errors.New("id is empty"), ctx)
		return
	}
	title := ctx.Query("title")
	if len(title) == 0 {
		httpErrorBadRequest(errors.New("title is empty"), ctx)
		return
	}
	video := &Video{
		ID:    id,
		Title: title,
	}
	if strings.ToLower(os.Getenv("DB")) == "fs" {
		videos, err := getVideosFromFile()
		if err != nil {
			httpErrorInternalServerError(err, ctx)
			return
		}
		videos = append(videos, *video)
		dir := os.Getenv("FS_DIR")
		if len(dir) == 0 {
			dir = "/cache"
		}
		path := fmt.Sprintf("%s/videos.yaml", dir)
		yamlData, err := yaml.Marshal(videos)
		if err != nil {
			httpErrorInternalServerError(err, ctx)
			return
		}
		err = os.WriteFile(path, yamlData, 0644)
		if err != nil {
			httpErrorInternalServerError(err, ctx)
		}
	} else {
		db := getDB(ctx)
		if db == nil {
			return
		}
		_, err := db.ModelContext(ctx, video).Insert()
		if err != nil {
			httpErrorInternalServerError(err, ctx)
			return
		}
	}
}
