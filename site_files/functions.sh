# Functions to be used with command

set_option() {
  case $1 in
    V)
      printf "Version: ${version}\n"
      exit 1
      ;;
    f)
      framework="${OPTARG}"
      case $framework in
        "ci"|"CI"|"Ci"|"codeigniter"|"CodeIgniter"|"Codeigniter")
          framework="ci"
          printf "Framework CodeIgniter will be installed.\n"
          ;;
        *)
          printf "Framework not recognized, proceeding with basic install.\n"
          ;;
      esac
      ;;
    g)
      git=true
      printf "Git initialization enabled.\n"
      ;;
    v)
      verbose=true
      printf "Verbose mode enabled.\n"
      ;;
    d)
      delete=true
      printf "Delete mode enabled.\n"
      ;;
    w)
      wizard=true
      printf "Configuration wizard enabled.\n"
      ;;
    h)
      help=true
      printf "Help mode enabled.\n"
      ;;
    \?)
      printf "Invalid option: -${OPTARG}\n"
      exit 1
      ;;
    :)
      printf "Option -${OPTARG} requires an argument.\n"
      exit 1
      ;;
  esac
}

# $1 path to .cfg
initialize_command() {
  source "$1"
  config_keys=("conf_root" "project_root" "user" "group" "permission" "default_init_git")
  config_values=("${conf_root}" "${project_root}" "${user}" "${group}" "${permission}" "${default_init_git}")
  config_help=(
    "conf_root is the root path to your http configuration files.  Example: /etc/httpd/sites-available/" 
    "project_root is the root path of your project.  Example: /var/www/" 
    "user is the user to assign file ownership.  Example: john" 
    "group is the group to assign file ownership.  Example: admins" 
    "permission is the permission level to assign files.  Example: 0775" 
    "default_init_git will initialize git regardless of the option flag being used if set to true"
  )
  for k in ${!config_values[@]}; do
    if [ "${config_values[$k]}" == "" ]; then
      printf "${config_keys[$k]} not defined.\n"
      printf "Please assign ${config_keys[$k]} a value or leave empty to skip\n"
      config_prompt $k
    fi
  done
  for k in ${!config_values[@]}; do
    if [ "${config_values[$k]}" == "" ]; then
      printf "One or more configuration settings have not been set.  View undefined settings(y/n)? "
      confirm
      initialize_command $1
    fi
  done
  build_config
  if [ ! -f "${command_root}http_config_template" ]; then
    printf "http_config_template not found.\n"
    echo "Project setup halted."
    exit 1
  fi
  if [ ! -f "${command_root}gitignore_template" ]; then
    printf "gitignore_template not found.\n"
  fi
}

config_wizard() {
  printf "==============================\n"
  printf "||   Configuration Wizard   ||\n"
  printf "==============================\n"
  config_menu
  printf "Configuration wizard completed.\n"
  exit 1
}

config_menu() {
  printf "\n"
  printf "1) Update configuration settings\n"
  printf "2) Import template file\n"
  printf "3) Edit template file\n"
  printf "4) Exit\n"
  printf "Enter Choice: "
  read -r cmenu
  case $cmenu in
    1)
      config_settings
      ;;
    2)
      template_menu "import"
      ;;
    3)
      template_menu "edit"
      ;;
    4)
      return 0
      ;;
  esac
  config_menu
}

config_settings() {
  for k in ${!config_values[@]}; do
    printf "${config_keys[$k]}: ${config_values[$k]}\n"
  done
  printf "\n"
  printf "Please assign each setting a new value or leave empty to skip\n"
  for k in ${!config_values[@]}; do
    config_prompt $k
  done
  build_config
}

# $1 config index
config_prompt() {
  printf "${config_help[$1]}\n"
  printf "${config_keys[$1]}: "
  read -r config_wizard_input
  if [ "${config_wizard_input}" != "" ]; then
    config_values[$1]="${config_wizard_input}"
    if $(grep -q "^${config_keys[$1]}=.*" "${command_root}$command.cfg"); then
      sed -i "s~^${config_keys[$1]}=.*~${config_keys[$1]}=\"${config_values[$1]}\"~" "${command_root}$command.cfg"
    else
      echo "${config_keys[$1]}=\"${config_values[$1]}\"" >> "${command_root}$command.cfg"
    fi
  fi
}

build_config() {
  conf_path="${config_values[0]}${site}.conf"
  project_path="${config_values[1]}${site}"
  user="${config_values[2]}"
  group="${config_values[3]}"
  permission="${config_values[4]}"
  git="${config_values[5]}"
}

# $1 action
template_menu() {
  if [ $1 == "import" ]; then
    printf "Choose destination template file where import will be copied\n"
  fi
  if [ $1 == "edit" ]; then
    printf "Choose template file to edit\n"
  fi
  printf "\n"
  printf "1) http_config_template\n"
  printf "2) index_template\n"
  printf "3) gitignore_template\n"
  printf "4) Back\n"
  printf "Enter Choice: "
  read -r tmenu
  case $tmenu in
    1)
      if [ $1 == "import" ]; then
        import_template "http_config_template"
      fi
      if [ $1 == "edit" ]; then
        vi ${command_root}http_config_template
      fi
      ;;
    2)
      if [ $1 == "import" ]; then
        import_template "index_template"
      fi
      if [ $1 == "edit" ]; then
        vi ${command_root}index_template
      fi
      ;;
    3)
      if [ $1 == "import" ]; then
        import_template "gitignore_template"
      fi
      if [ $1 == "edit" ]; then
        vi ${command_root}gitignore_template
      fi
      ;;
    4)
      return 0
      ;;
  esac
  template_menu $1
}

# $1 destination template file
import_template() {
  printf "\n"
  printf "Full path of file to import for $1: "
  read -r import
  if [ "${import}" != "" ] && [ -f "${import}" ]; then
    cp $import ${command_root}$1
    printf "Copied $import to ${command_root}$1\n"
  else
    printf "Import canceled.\n"
  fi
}

delete_project() {
  if [ -f "${conf_path}" ];then
    IFS=' ' read -ra line <<< "$(grep CustomLog ${conf_path})"
    access_path="${line[1]}"
    IFS=' ' read -ra line <<< "$(grep ErrorLog ${conf_path})"
    error_path="${line[1]}"
    log_path="$(dirname "$access_path")"
    if [ "${log_path}" == "." ];then
      log_path="$(dirname "$error_path")"
    fi
  fi
  if [ -f "${conf_path}" ] || ([ "${log_path}" != "." ] && [ -d "${log_path}" ]) || [ -d "${project_path}" ];then
    printf "The following files will be permanently deleted:\n"
    if [ -f "${conf_path}" ];then
      printf "${conf_path}\n"
    fi
    if [ "${log_path}" != "." ] && [ -d "${log_path}" ];then
      printf "${log_path}\n"
    fi
    if [ -d "${project_path}" ];then
      printf "${project_path}\n"
    fi
    printf "Are you sure you want to delete these files(y/n)? "
    confirm
    rm -f "${conf_path}"
    rm -rf "${log_path}"
    rm -rf "${project_path}"
    printf "Project has been deleted!\n"
    exit 1
  else
    printf "No files to delete.  Delete mode halted.\n"
    exit 1
  fi
}

# $1 error
# $2 message
handle_error() {
  case $1 in
    0)
      return 0
      ;;
    1)
      echo "$2 (Permission Denied)"
      exit 1
      ;;
    *)
      echo "$2 (Error $1)"
      exit 1
      ;;
  esac
}

confirm() {
  read -r confirm
  case $confirm in
    "y"|"Y"|"yes"|"YES"|"Yes")
      return 0
      ;;
    "n"|"N"|"no"|"NO"|"No")
      echo "Project setup halted."
      exit 1
      ;;
    *)
      confirm
      ;;
  esac
}

# $1 output
verbose_output() {
  if "$verbose"; then
    printf "$1\n"
  fi
}

write_http_config() {
  if [ -f ${conf_path} ]; then
    printf "File ${conf_path} already exists, overwrite(y/n)? "
    confirm
  fi
  template=$(cat ${command_root}http_config_template)
  echo "${template//\{site\}/$site}" 2> /dev/null > ${conf_path}
  handle_error $? "Failed trying to create file: ${conf_path}"
}

# $1 path
create_directory() {
  if [ -d "$1" ]; then
    printf "Directory $1 already exists, overwrite(y/n)? "
    confirm
    rm -rf $1
  fi
  mkdir $1 2> /dev/null
  handle_error $? "Failed trying to create directory: $1"
}

# $1 path
create_file() {
  if [ -f "$1" ]; then
    printf "File $1 already exists, overwrite(y/n)? "
    confirm
    rm -f $1
  fi
  touch $1 2> /dev/null
  handle_error $? "Failed trying to create file: $1"
}

# $1 framework
install_framework() {
  if [ "$1" == "ci" ]; then
    printf "Downloading CodeIgniter...\n"
    if $(wget https://github.com/bcit-ci/CodeIgniter/archive/3.1.9.zip -O ${project_path}/ci.zip 2> /dev/null); then
      if $(unzip -qq ${project_path}/ci.zip -d ${project_path}/unzipped/ 2> /dev/null); then
        if $(cp -a ${project_path}/unzipped/CodeIgniter*/. ${project_path}/html/ 2> /dev/null); then
          rm -rf ${project_path}/unzipped/ 2> /dev/null
          rm -f ${project_path}/ci.zip
          rm -rf ${project_path}/html/user_guide/
          printf "Codeigniter installed at ${project_path}/html\n"
        else
          printf "There was a problem copying unzipped CodeIgniter files: (Error $?)\n"
          exit 1
        fi
      else
        printf "There was a problem unzipping CodeIgniter: (Error $?)\n"
        exit 1
      fi
    else
      printf "There was a problem downloading CodeIgniter: (Error $?)\n"
      exit 1
    fi
  fi
}
