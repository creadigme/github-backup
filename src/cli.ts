/**
 * MIT Licenced. https://github.com/creadigme/github-backup
 */

import * as fs from "node:fs/promises";
import * as path from "node:path";
import { execSync } from "node:child_process";

async function getRepositories({
  url,
  token,
}: {
  url: string;
  token?: string;
}): Promise<unknown[]> {
  const repositoriesResp = await fetch(url, {
    headers: token
      ? {
          Authorization: `token ${token}`,
        }
      : undefined,
  });
  const repositoriesResult = await repositoriesResp.json();

  if (repositoriesResp.ok) {
    return repositoriesResult;
  } else {
    throw new Error(JSON.stringify(repositoriesResult, undefined, 2));
  }
}

async function mirrorCloneRepository({
  git,
  gitUrl,
  repoPath,
  canFail = false,
}: {
  git: string;
  gitUrl: string;
  repoPath: string;
  canFail?: boolean;
}) {

  try {
    if (await fs.access(path.join(repoPath, 'HEAD'), fs.constants.R_OK).then(() => true). catch(() => false)) {
      console.log(`Updating repo (--mirror): ${gitUrl} to ${repoPath}...`);

      // Update
      execSync(`${git} remote update`, {
        cwd: repoPath,
      });
    } else {
      // Create a bare clone of the repository
      console.log(`Cloning repo (--mirror): ${gitUrl} to ${repoPath}...`);
      execSync(`${git} clone --mirror ${gitUrl} ${repoPath}`);
    }

    // Pull in the repository's Git Large File Storage objects.
    execSync(`${git} lfs fetch --all`, {
      cwd: repoPath,
    });
  } catch (error: any) {
    if (error?.stderr) {
      error.message += '\n' + error.stderr.toString();
    }

    if (canFail) {
      console.error(error);
    } else {
      throw error;
    }
  }
}

async function main() {
  const {
    GIT: gitPath,
    GITHUB_BACKUP_TOKEN: token,
    GITHUB_BACKUP_PATH: backupPath,
    GITHUB_BACKUP_USER: backupUser,
  } = process.env;

  if (!backupPath) {
    throw new Error(`You must specify GITHUB_BACKUP_PATH env.`);
  }

  if (!token && !backupUser) {
    throw new Error(`You must specify GITHUB_BACKUP_USER env.`);
  }

  const git = gitPath || "git";
  const apiURLBase = token
    ? "https://api.github.com/user"
    : `https://api.github.com/users/${backupUser}`;

  let totalCounter = 0;
  let url: string;
  let repositories: any[];
  let page = 1;

  do {
    url = `${apiURLBase}/repos?type=all&per_page=100&page=${page++}`;

    console.log(`Fetching from ${url}...`);
    repositories = await getRepositories({ url, token });
    totalCounter += repositories.length;

    for (let repo of repositories) {
      const repoPath = path.resolve(backupPath, repo.full_name);

      await fs.mkdir(repoPath, {
        recursive: true,
      });

      await mirrorCloneRepository({
        git,
        gitUrl: token ? `https://oauth2:${token}@github.com/${repo.full_name}.git` : `https://github.com/${repo.full_name}.git`,
        repoPath: path.join(repoPath, "code"),
      });

      if (repo.has_wiki) {
        await mirrorCloneRepository({
          git,
          gitUrl: token ? `https://oauth2:${token}@github.com/${repo.full_name}.wiki.git` : `https://github.com/${repo.full_name}.wiki.git`,
          repoPath: path.join(repoPath, "wiki"),
          canFail: true,
        });
      }

      if (repo.private === true) {
        await fs.writeFile(path.join(repoPath, "private"), "true", "utf-8");
      }
    }

    // if we get less than 100 repositories, it's the end.
  } while (repositories.length === 100);

  return {
    totalCounter,
  };
}

main()
  .then(({ totalCounter }: { totalCounter: number }) => {
    console.log(`${totalCounter} repositories updated.`);
    process.exit(0);
  })
  .catch((error) => {
    console.error(error);
    process.exit(-1);
  });
