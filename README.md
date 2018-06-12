# Jenkins S2I Example

An example demonstrating creation of custom Jenkins image with S2I features for installing plugins, configuring jobs, Jenkins, etc and using slave pods for Jenkins jobs.
This is for OpenShift v3.6

## Installation

1. Create a new OpenShift project, where the Jenkins server will run:

  ```
  $ oc new-project ci --display-name="CI/CD"
  ```

2. Install the provided OpenShift templates:

  ```
  $ oc create -f jenkins-slave-builder-template.yaml   # For converting any S2I to Jenkins slave
  $ oc create -f jenkins-master-template.yaml  # For building Jenkins master image
  $ oc create -f jenkins-ephemeral-template.yaml # For deploying Jenkins instance
  $ oc create -f jenkins-extend-template.yaml #  For s2i build

  ```

3. Build Jenkins slave image.

  ```
  $ oc new-app jenkins-slave-builder
  ```

4. Build Jenkins master
  
  ```
  $ oc new-app jenkins-master
  $ oc start-build jenkins-base
  ```

5. Deploy Jenkins master (by default uses slave from public docker registery, use MAVEN_SLAVE_IMAGE and JENKINS_SLAVE_IMAGE_TAG environment variables in dc to change or update manually in Jenkins UI)

  ```	
  $ Add to Project -> Browse Catalog -> select Jenkins (Ephemeral) in your project  
  ```

6. Use s2i to customize Jenkins 

  ```	
  $ oc new-app jenkins-extend
  ```

7. Deploy customized image with Ui or update existing deployment config