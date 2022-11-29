/**
 * MIT Licenced. https://github.com/creadigme/github-backup
 */

import * as fs from "node:fs/promises";
import * as path from "node:path";
import { execSync } from "node:child_process";

async function pathExists(fileOrDir: string): Promise<boolean> {
  return await fs.access(fileOrDir, fs.constants.R_OK).then(() => true). catch(() => false)
}

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
  repo,
  git,
  gitUrl,
  repoPath,
  canFail = false,
}: {
  repo: {
    full_name: string
  },
  git: string;
  gitUrl: string;
  repoPath: string;
  canFail?: boolean;
}) {

  try {
    // prevent "detected dubious ownership in repository"
    execSync(`${git} config --global --add safe.directory ${repoPath}`);

    const gitLastPart = gitUrl.slice(gitUrl.lastIndexOf('/'));
    if (await pathExists(path.join(repoPath, 'HEAD'))) {
      console.log(`Updating repo: ${repo.full_name} (${gitLastPart})...`);
      // We set the credentials again
      execSync(`${git} remote add origin --mirror=fetch ${gitUrl}`, {
        cwd: repoPath,
      });

      // Update
      execSync(`${git} remote update`, {
        cwd: repoPath,
      });
    } else {
      // Create a bare clone of the repository
      console.log(`Cloning repo: ${repo.full_name} (${gitLastPart})...`);
      execSync(`${git} clone --mirror ${gitUrl} ${repoPath}`);
    }

    if (await pathExists(path.join(repoPath, 'HEAD'))) {
      // Pull in the repository's Git Large File Storage objects.
      execSync(`${git} lfs fetch --all`, {
        cwd: repoPath,
      });
    }
  } catch (error: any) {
    error.message = (error.message as string).replace(/https:\/\/oauth2:(.*)\@github\.com/g, '***');
    if (canFail) {
      console.warn(error.message);
    } else {
      throw error;
    }
  } finally {
    if (await pathExists(path.join(repoPath, 'config'))) {
      // We don't keep the credentials
      execSync(`${git} remote remove origin`, {
        cwd: repoPath,
      });
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

  console.log(`Backup directory: ${path.resolve(backupPath)}`);
  if (!await pathExists(backupPath)) {
    await fs.mkdir(backupPath, {
      recursive: true,
    });
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
        repo,
        git,
        gitUrl: token ? `https://oauth2:${token}@github.com/${repo.full_name}.git` : `https://github.com/${repo.full_name}.git`,
        repoPath: path.join(repoPath, "code"),
      });

      if (repo.has_wiki) {
        await mirrorCloneRepository({
          repo,
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
    if (error?.stderr) {
      const strerr = error.stderr.toString();
      if (error.message.indexOf(strerr) === -1) {
        error.message += '\n' + strerr;
      }
    }

    console.error(error);
    process.exit(-1);
  });
