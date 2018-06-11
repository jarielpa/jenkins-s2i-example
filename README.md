# Jenkins S2I Example

An example demonstrating custom Jenkins image with S2I features for installing plugins, configuring jobs, Jenkins, etc and using slave pods for Jenkins jobs.
This is for OpenShift v3.6

## Installation

1. Create a new OpenShift project, where the Jenkins server will run:

  ```
  $ oc new-project ci --display-name="CI/CD"
  ```

2. Give the Jenkins Pod service account rights to do API calls to OpenShift. This allows us to do the Jenkins Slave image discovery automatically.

  ```
  $ oc policy add-role-to-user edit -z default -n ci
  ```

3. Install the provided OpenShift templates:

  ```
  $ oc create -f jenkins-slave-builder-template.yaml   # For converting any S2I to Jenkins slave

  ```

5. Build Jenkins slave image.

  ```
  $ oc new-app jenkins-slave-builder
  ```

4. Create Jenkins master

TODO
