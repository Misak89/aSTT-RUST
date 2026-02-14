// Integration tests for Tauri greet command
// These tests run in CI even without local Rust installation

#[cfg(test)]
mod tests {
    use crate::greet;

    #[test]
    fn test_greet_contains_name() {
        let result = greet("World");
        assert!(result.contains("World"), "Expected 'World' in greeting");
    }

    #[test]
    fn test_greet_format() {
        let result = greet("Test");
        assert!(
            result.starts_with("Hello,"),
            "Expected greeting to start with 'Hello,'"
        );
        assert!(
            result.contains("You've been greeted from Rust!"),
            "Expected standard greeting message"
        );
    }

    #[test]
    fn test_greet_empty_name() {
        let result = greet("");
        assert!(result.contains("Hello,"), "Should handle empty name gracefully");
    }

    #[test]
    fn test_greet_special_characters() {
        let result = greet("José García");
        assert!(result.contains("José García"));
    }
}
// These tests run in CI even without local Rust installation

#[cfg(test)]
mod tests {
    use crate::greet;

    #[test]
    fn test_greet_contains_name() {
        let result = greet("World");
        assert!(result.contains("World"), "Expected 'World' in greeting");
    }

    #[test]
    fn test_greet_format() {
        let result = greet("Test");
        assert!(
            result.starts_with("Hello,"),
            "Expected greeting to start with 'Hello,'"
        );
        assert!(
            result.contains("You've been greeted from Rust!"),
            "Expected standard greeting message"
        );
    }

    #[test]
    fn test_greet_empty_name() {
        let result = greet("");
        assert!(result.contains("Hello,"), "Should handle empty name gracefully");
    }

    #[test]
    fn test_greet_special_characters() {
        let result = greet("José García");
        assert!(result.contains("José García"));
    }
}

