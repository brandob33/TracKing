/* eslint-disable */
// this is an auto generated file. This will be overwritten

export const onCreateUser = /* GraphQL */ `
  subscription OnCreateUser(
    $filter: ModelSubscriptionUserFilterInput
    $owner: String
  ) {
    onCreateUser(filter: $filter, owner: $owner) {
      id
      username
      email
      role
      workouts {
        nextToken
        __typename
      }
      createdAt
      updatedAt
      owner
      __typename
    }
  }
`;
export const onUpdateUser = /* GraphQL */ `
  subscription OnUpdateUser(
    $filter: ModelSubscriptionUserFilterInput
    $owner: String
  ) {
    onUpdateUser(filter: $filter, owner: $owner) {
      id
      username
      email
      role
      workouts {
        nextToken
        __typename
      }
      createdAt
      updatedAt
      owner
      __typename
    }
  }
`;
export const onDeleteUser = /* GraphQL */ `
  subscription OnDeleteUser(
    $filter: ModelSubscriptionUserFilterInput
    $owner: String
  ) {
    onDeleteUser(filter: $filter, owner: $owner) {
      id
      username
      email
      role
      workouts {
        nextToken
        __typename
      }
      createdAt
      updatedAt
      owner
      __typename
    }
  }
`;
export const onCreateWorkout = /* GraphQL */ `
  subscription OnCreateWorkout(
    $filter: ModelSubscriptionWorkoutFilterInput
    $owner: String
  ) {
    onCreateWorkout(filter: $filter, owner: $owner) {
      id
      title
      date
      status
      athleteId
      coachId
      exercises {
        nextToken
        __typename
      }
      createdAt
      updatedAt
      userWorkoutsId
      owner
      __typename
    }
  }
`;
export const onUpdateWorkout = /* GraphQL */ `
  subscription OnUpdateWorkout(
    $filter: ModelSubscriptionWorkoutFilterInput
    $owner: String
  ) {
    onUpdateWorkout(filter: $filter, owner: $owner) {
      id
      title
      date
      status
      athleteId
      coachId
      exercises {
        nextToken
        __typename
      }
      createdAt
      updatedAt
      userWorkoutsId
      owner
      __typename
    }
  }
`;
export const onDeleteWorkout = /* GraphQL */ `
  subscription OnDeleteWorkout(
    $filter: ModelSubscriptionWorkoutFilterInput
    $owner: String
  ) {
    onDeleteWorkout(filter: $filter, owner: $owner) {
      id
      title
      date
      status
      athleteId
      coachId
      exercises {
        nextToken
        __typename
      }
      createdAt
      updatedAt
      userWorkoutsId
      owner
      __typename
    }
  }
`;
export const onCreateExercise = /* GraphQL */ `
  subscription OnCreateExercise(
    $filter: ModelSubscriptionExerciseFilterInput
    $owner: String
  ) {
    onCreateExercise(filter: $filter, owner: $owner) {
      id
      name
      sets {
        reps
        distance
        completed
        __typename
      }
      createdAt
      updatedAt
      workoutExercisesId
      owner
      __typename
    }
  }
`;
export const onUpdateExercise = /* GraphQL */ `
  subscription OnUpdateExercise(
    $filter: ModelSubscriptionExerciseFilterInput
    $owner: String
  ) {
    onUpdateExercise(filter: $filter, owner: $owner) {
      id
      name
      sets {
        reps
        distance
        completed
        __typename
      }
      createdAt
      updatedAt
      workoutExercisesId
      owner
      __typename
    }
  }
`;
export const onDeleteExercise = /* GraphQL */ `
  subscription OnDeleteExercise(
    $filter: ModelSubscriptionExerciseFilterInput
    $owner: String
  ) {
    onDeleteExercise(filter: $filter, owner: $owner) {
      id
      name
      sets {
        reps
        distance
        completed
        __typename
      }
      createdAt
      updatedAt
      workoutExercisesId
      owner
      __typename
    }
  }
`;
