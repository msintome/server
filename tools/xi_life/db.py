# -*- coding: utf-8 -*-
"""Shared database access for the XI_LIFE generators."""

import os
import sys

try:
    import mariadb
except ImportError:
    sys.exit("mariadb module not found. Run: pip install -r tools/requirements.txt")


REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def fetch_credentials():
    """Read settings/network.lua, with the same environment overrides dbtool honours."""

    settings = {}
    network_path = os.path.join(REPO_ROOT, "settings", "network.lua")

    if os.path.exists(network_path):
        with open(network_path, encoding="utf-8") as handle:
            for line in handle:
                if "=" not in line or line.strip().startswith("--"):
                    continue

                key, value = line.split("=", 1)
                settings[key.strip()] = value.strip().rstrip(",").strip("'\" ")

    def setting(name, fallback):
        return os.getenv("XI_NETWORK_" + name) or settings.get(name, fallback)

    return {
        "host": setting("SQL_HOST", "127.0.0.1"),
        "port": int(setting("SQL_PORT", 3306)),
        "user": setting("SQL_LOGIN", "root"),
        "password": setting("SQL_PASSWORD", ""),
        "database": setting("SQL_DATABASE", "xidb"),
    }


def connect():
    credentials = fetch_credentials()
    print(
        "Connecting to {}@{}:{}/{}".format(
            credentials["user"],
            credentials["host"],
            credentials["port"],
            credentials["database"],
        )
    )

    try:
        return mariadb.connect(**credentials)
    except mariadb.Error as error:
        sys.exit("Could not connect to the database: {}".format(error))


def text(value):
    """The connector hands back tinytext columns as bytes, so normalise everything to str."""

    if isinstance(value, (bytes, bytearray)):
        return value.decode("utf-8", "replace")

    return value
